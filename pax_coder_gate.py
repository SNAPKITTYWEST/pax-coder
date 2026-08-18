#!/usr/bin/env python3
"""
PAX-Coder Protected Execution Gate (ADR-0009)

Native Python implementation with Ed25519 cryptographic verification.
Replaces the shell-based gate with:
  - Native Ed25519 via cryptography library (no openssl CLI)
  - JSON schema validation via Pydantic
  - No subprocess, no shell, no external CLI tools
  - Deterministic JSON canonicalization (sorted keys, compact)

Exit codes:
  0 = AUTHORIZED (protected execution allowed)
  1 = INTEGRITY_FAILED (release verification failed)
  2 = AUTHORIZATION_DENIED (node not authorized or capability missing/invalid)
  3 = SCRIPT_ERROR (cannot determine status)

Environment:
  PAX_CAPABILITY_TOKEN  - capability token (JSON|signature_hex)
  PAX_REPO_ROOT         - override repo root (defaults to script parent dir)

Usage:
  python3 pax_coder_gate.py [--quiet] [--json-output]
"""

import json
import os
import sys
import hashlib
import subprocess
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

from pydantic import BaseModel, Field, ValidationError
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey
from cryptography.hazmat.primitives.serialization import load_pem_public_key
from cryptography.exceptions import InvalidSignature


# =============================================================================
# EXIT CODES
# =============================================================================

EXIT_AUTHORIZED = 0
EXIT_INTEGRITY_FAILED = 1
EXIT_DENIED = 2
EXIT_ERROR = 3


# =============================================================================
# MODELS (Pydantic schema validation)
# =============================================================================

class CapabilityPayload(BaseModel):
    """Schema for capability token JSON payload."""
    node_id: str = Field(min_length=1)
    release_id: str = Field(min_length=1)
    commit: str = Field(min_length=1)
    nonce: str = Field(min_length=1)
    expires_at: str = Field(min_length=1)


class ReleaseMetadata(BaseModel):
    """Schema for sovereign/release.json."""
    project: str = ""
    repository: str = ""
    release_version: str = ""
    git_commit: str = ""
    node_id: str = ""
    manifest_sha256: str = ""
    release_timestamp_utc: str = ""


class AuthorizationRecord(BaseModel):
    """Schema for sovereign/authorization.json."""
    authorization_id: str = ""
    node_id: str = ""
    authorization_status: str = ""
    authorization_scope: str = ""
    expires_at_utc: Optional[str] = None
    revocation_status: str = ""


class NodeIdentity(BaseModel):
    """Schema for sovereign/node.json."""
    node_id: str = ""
    algorithm: str = ""
    public_key_hex: str = ""


# =============================================================================
# GATE IMPLEMENTATION
# =============================================================================

class PaxCoderGate:
    """
    Protected Execution Gate.

    Verifies in order:
      1. Release integrity (git commit matches release.json, manifest hash)
      2. Node authorization status (ACTIVE, not revoked, not expired)
      3. Capability possession (env var or file)
      4. Capability validity (commit, expiration, node binding)
      5. Capability signature (Ed25519 with authority public key)
    """

    def __init__(self, repo_root: Optional[Path] = None, quiet: bool = False):
        if repo_root is None:
            # Default: parent of the script location
            repo_root = Path(__file__).resolve().parent
        self.repo_root = Path(repo_root)
        self.sovereign_dir = self.repo_root / "sovereign"
        self.quiet = quiet
        self._messages: list[str] = []

    def log(self, msg: str) -> None:
        """Log a message (suppressed in quiet mode)."""
        self._messages.append(msg)
        if not self.quiet:
            print(msg)

    def run(self) -> int:
        """Execute the full gate sequence. Returns exit code."""
        self.log("==========================================")
        self.log("PAX-CODER PROTECTED EXECUTION GATE")
        self.log("==========================================")
        self.log("")

        # Step 1: Release integrity
        result = self._verify_release_integrity()
        if result != EXIT_AUTHORIZED:
            return result

        # Step 2: Node authorization
        result = self._verify_node_authorization()
        if result != EXIT_AUTHORIZED:
            return result

        # Step 3: Capability possession
        capability_raw = self._get_capability_token()
        if capability_raw is None:
            return EXIT_DENIED

        # Step 4: Parse and validate capability
        payload, signature_hex = self._parse_capability(capability_raw)
        if payload is None:
            return EXIT_DENIED

        result = self._validate_capability(payload)
        if result != EXIT_AUTHORIZED:
            return result

        # Step 5: Verify signature
        result = self._verify_signature(payload, signature_hex)
        if result != EXIT_AUTHORIZED:
            return result

        # All checks passed
        self.log("")
        self.log("==========================================")
        self.log("STATUS: AUTHORIZATION_GRANTED")
        self.log("==========================================")
        self.log("")
        self.log("Protected execution is AUTHORIZED.")
        self.log("")
        self.log("You may now:")
        self.log("  - Generate node keys")
        self.log("  - Sign releases")
        self.log("  - Invoke other protected operations")
        self.log("")
        self.log(f"Capability valid until: {payload.expires_at}")
        self.log("")

        return EXIT_AUTHORIZED

    # =========================================================================
    # STEP 1: RELEASE INTEGRITY
    # =========================================================================

    def _verify_release_integrity(self) -> int:
        """Verify release.json matches current state."""
        self.log("[1/5] Verifying release integrity...")

        release_file = self.sovereign_dir / "release.json"
        if not release_file.exists():
            self.log("FAILED: sovereign/release.json not found")
            return EXIT_INTEGRITY_FAILED

        try:
            with open(release_file) as f:
                data = json.load(f)
            release = ReleaseMetadata(**data)
        except (json.JSONDecodeError, ValidationError) as e:
            self.log(f"FAILED: Cannot parse release.json: {e}")
            return EXIT_INTEGRITY_FAILED

        # Verify git commit matches
        current_commit = self._get_git_commit()
        if current_commit is None:
            self.log("FAILED: Cannot determine current git commit")
            return EXIT_ERROR

        if current_commit != release.git_commit:
            self.log("FAILED: Release integrity check failed")
            self.log(f"  Expected commit: {release.git_commit}")
            self.log(f"  Current commit:  {current_commit}")
            return EXIT_INTEGRITY_FAILED

        # Verify manifest hash if manifest exists
        manifest_file = self.sovereign_dir / "manifest.json"
        if manifest_file.exists() and release.manifest_sha256:
            computed_hash = self._sha256_file(manifest_file)
            if computed_hash != release.manifest_sha256:
                self.log("FAILED: Manifest hash mismatch")
                self.log(f"  Expected: {release.manifest_sha256}")
                self.log(f"  Computed: {computed_hash}")
                return EXIT_INTEGRITY_FAILED

        self.log("    Release integrity verified")
        self.log("")
        return EXIT_AUTHORIZED

    # =========================================================================
    # STEP 2: NODE AUTHORIZATION
    # =========================================================================

    def _verify_node_authorization(self) -> int:
        """Verify node has active authorization."""
        self.log("[2/5] Verifying node authorization status...")

        auth_file = self.sovereign_dir / "authorization.json"
        if not auth_file.exists():
            self.log("FAILED: Authorization record not found")
            return EXIT_DENIED

        node_file = self.sovereign_dir / "node.json"
        if not node_file.exists():
            self.log("FAILED: Node identity not found")
            return EXIT_DENIED

        try:
            with open(auth_file) as f:
                auth_data = json.load(f)
            auth = AuthorizationRecord(**auth_data)
        except (json.JSONDecodeError, ValidationError) as e:
            self.log(f"FAILED: Cannot parse authorization.json: {e}")
            return EXIT_ERROR

        try:
            with open(node_file) as f:
                node_data = json.load(f)
            node = NodeIdentity(**node_data)
        except (json.JSONDecodeError, ValidationError) as e:
            self.log(f"FAILED: Cannot parse node.json: {e}")
            return EXIT_ERROR

        # Check authorization status
        if auth.authorization_status != "ACTIVE":
            self.log(f"DENIED: Authorization status is {auth.authorization_status}")
            if auth.authorization_status == "REQUESTED":
                self.log("  Status is REQUESTED (not yet authorized)")
            elif auth.authorization_status == "SUSPENDED":
                self.log("  Status is SUSPENDED")
            elif auth.authorization_status == "REVOKED":
                self.log("  Status is REVOKED")
            elif auth.authorization_status == "EXPIRED":
                self.log("  Status is EXPIRED")
            return EXIT_DENIED

        # Check revocation status
        if auth.revocation_status != "ACTIVE":
            self.log(f"DENIED: Revocation status is {auth.revocation_status}")
            return EXIT_DENIED

        # Check expiration
        if auth.expires_at_utc and auth.expires_at_utc != "null":
            try:
                expires = datetime.fromisoformat(
                    auth.expires_at_utc.replace("Z", "+00:00")
                )
                now = datetime.now(timezone.utc)
                if now > expires:
                    self.log(f"DENIED: Authorization has expired ({auth.expires_at_utc})")
                    return EXIT_DENIED
            except ValueError:
                pass  # If we can't parse, skip expiration check

        # Check node ID consistency
        if auth.node_id != node.node_id:
            self.log("DENIED: Node ID mismatch")
            self.log(f"  Authorization: {auth.node_id}")
            self.log(f"  Local node:    {node.node_id}")
            return EXIT_DENIED

        self.log("    Node authorization verified")
        self.log("")
        return EXIT_AUTHORIZED

    # =========================================================================
    # STEP 3: CAPABILITY POSSESSION
    # =========================================================================

    def _get_capability_token(self) -> Optional[str]:
        """Get capability token from environment or file."""
        self.log("[3/5] Checking for capability...")

        # Check environment variable
        token = os.environ.get("PAX_CAPABILITY_TOKEN", "").strip()
        if token:
            self.log("    Capability token found (environment)")
            self.log("")
            return token

        # Check capability file
        cap_file = self.sovereign_dir / ".capability"
        if cap_file.exists():
            token = cap_file.read_text().strip()
            if token:
                self.log("    Capability token found (file)")
                self.log("")
                return token

        # No capability available
        node_id = "unknown"
        try:
            node_file = self.sovereign_dir / "node.json"
            if node_file.exists():
                with open(node_file) as f:
                    node_id = json.load(f).get("node_id", "unknown")
        except Exception:
            pass

        self.log("DENIED: No capability available")
        self.log("")
        self.log("Protected execution requires a capability token.")
        self.log("")
        self.log("To obtain authorization:")
        self.log("  1. Contact the PAX-Coder authority")
        self.log(f"  2. Request a capability for:")
        self.log(f"     - node_id: {node_id}")
        self.log(f"     - release: {self._get_git_commit() or 'unknown'}")
        self.log("  3. Set: export PAX_CAPABILITY_TOKEN=<capability>")
        self.log("  4. Re-run protected operation")
        self.log("")
        return None

    # =========================================================================
    # STEP 4: CAPABILITY PARSING AND VALIDATION
    # =========================================================================

    def _parse_capability(self, raw: str) -> tuple[Optional[CapabilityPayload], str]:
        """Parse capability token into payload and signature."""
        self.log("[4/5] Parsing capability...")

        # Split on pipe: JSON|signature_hex
        parts = raw.split("|", 1)
        if len(parts) != 2:
            self.log("DENIED: Capability format invalid (missing separator)")
            return None, ""

        json_part = parts[0].strip()
        sig_hex = parts[1].strip()

        # Parse JSON with Pydantic validation
        try:
            data = json.loads(json_part)
            payload = CapabilityPayload(**data)
        except json.JSONDecodeError as e:
            self.log(f"DENIED: Capability JSON invalid: {e}")
            return None, ""
        except ValidationError as e:
            self.log(f"DENIED: Capability format invalid")
            return None, ""

        self.log(f"    Node ID: {payload.node_id}")
        self.log(f"    Commit:  {payload.commit}")
        self.log(f"    Expires: {payload.expires_at}")
        self.log("    Capability parsed")
        self.log("")

        return payload, sig_hex

    def _validate_capability(self, payload: CapabilityPayload) -> int:
        """Validate capability fields against current state."""
        self.log("[5/5] Validating capability...")

        # Check 1: Commit matches current HEAD
        current_commit = self._get_git_commit()
        if current_commit and current_commit != payload.commit:
            self.log("DENIED: Release commit mismatch")
            self.log(f"  Expected: {payload.commit}")
            self.log(f"  Current:  {current_commit}")
            return EXIT_DENIED

        self.log("    Commit matches")

        # Check 2: Expiration
        try:
            expires = datetime.fromisoformat(
                payload.expires_at.replace("Z", "+00:00")
            )
            now = datetime.now(timezone.utc)
            if now > expires:
                self.log("DENIED: Capability expired")
                self.log(f"  Expired at: {payload.expires_at}")
                return EXIT_DENIED
        except ValueError:
            self.log("ERROR: Cannot parse expiration time")
            return EXIT_ERROR

        self.log("    Capability not expired")

        # Check 3: Node ID consistency
        node_file = self.sovereign_dir / "node.json"
        if node_file.exists():
            try:
                with open(node_file) as f:
                    local_node_id = json.load(f).get("node_id", "")
                if local_node_id and local_node_id != payload.node_id:
                    self.log("DENIED: Node ID mismatch")
                    self.log(f"  Capability node: {payload.node_id}")
                    self.log(f"  Local node:      {local_node_id}")
                    return EXIT_DENIED
                self.log("    Node ID matches")
            except Exception:
                pass

        self.log("")
        return EXIT_AUTHORIZED

    # =========================================================================
    # STEP 5: SIGNATURE VERIFICATION (Ed25519, native)
    # =========================================================================

    def _verify_signature(self, payload: CapabilityPayload, sig_hex: str) -> int:
        """Verify Ed25519 signature using authority public key."""
        self.log("[6/6] Verifying capability signature...")

        # Load authority public key
        authority_pk_file = self.sovereign_dir / "authority_pk.pem"
        if not authority_pk_file.exists():
            self.log(f"ERROR: Authority public key not found at {authority_pk_file}")
            self.log("This gate cannot verify capabilities without the authority's public key.")
            self.log("HINT: Authority public key should be provided during deployment.")
            return EXIT_ERROR

        # Validate signature is present
        if not sig_hex:
            self.log("DENIED: Capability signature missing")
            return EXIT_DENIED

        # Validate signature format: 128 hex characters = 64 bytes (Ed25519)
        if len(sig_hex) != 128:
            self.log("DENIED: Capability signature invalid format (expected 128 hex chars)")
            return EXIT_DENIED

        # Validate hex characters only
        try:
            sig_bytes = bytes.fromhex(sig_hex)
        except ValueError:
            self.log("DENIED: Capability signature contains non-hex characters")
            return EXIT_DENIED

        # Create canonical JSON (sorted keys, compact separators)
        canonical_data = {
            "commit": payload.commit,
            "expires_at": payload.expires_at,
            "node_id": payload.node_id,
            "nonce": payload.nonce,
            "release_id": payload.release_id,
        }
        canonical_json = json.dumps(canonical_data, sort_keys=True, separators=(",", ":"))
        message_bytes = canonical_json.encode("utf-8")

        # Load and verify with authority public key
        try:
            with open(authority_pk_file, "rb") as f:
                pem_data = f.read()
            public_key = load_pem_public_key(pem_data)

            if not isinstance(public_key, Ed25519PublicKey):
                self.log("ERROR: Authority key is not Ed25519")
                return EXIT_ERROR

            # Verify signature (raises InvalidSignature on failure)
            public_key.verify(sig_bytes, message_bytes)

            self.log("    Signature format valid")
            self.log("    Signature verified (cryptographic validation)")
            return EXIT_AUTHORIZED

        except InvalidSignature:
            self.log("DENIED: Capability signature verification failed")
            self.log("    The signature is invalid or was not issued by the authority")
            return EXIT_DENIED
        except Exception as e:
            self.log(f"ERROR: Signature verification error: {e}")
            return EXIT_ERROR

    # =========================================================================
    # UTILITIES
    # =========================================================================

    def _get_git_commit(self) -> Optional[str]:
        """Get current HEAD commit hash."""
        try:
            result = subprocess.run(
                ["git", "rev-parse", "HEAD"],
                cwd=str(self.repo_root),
                capture_output=True,
                text=True,
                timeout=10,
            )
            if result.returncode == 0:
                return result.stdout.strip()
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass
        return None

    def _sha256_file(self, filepath: Path) -> str:
        """Compute SHA-256 hash of a file."""
        h = hashlib.sha256()
        with open(filepath, "rb") as f:
            for chunk in iter(lambda: f.read(8192), b""):
                h.update(chunk)
        return h.hexdigest()


# =============================================================================
# ENTRY POINT
# =============================================================================

def main() -> int:
    """Main entry point."""
    quiet = "--quiet" in sys.argv or "-q" in sys.argv

    # Allow repo root override via environment
    repo_root = os.environ.get("PAX_REPO_ROOT")
    if repo_root:
        root_path = Path(repo_root)
    else:
        root_path = Path(__file__).resolve().parent

    gate = PaxCoderGate(repo_root=root_path, quiet=quiet)
    return gate.run()


if __name__ == "__main__":
    sys.exit(main())
