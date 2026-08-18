% =====================================================================
% LICENSE POLICY ENGINE (Prolog Backend)
% =====================================================================

% Define available licenses
license(bsl_1_1).
license(agpl_3_0).
license(mpl_2_0).
license(commercial).

% Define use cases and map them to the optimal license tier
use_case(saas_wrapper, agpl_3_0).
use_case(enterprise_restricted, bsl_1_1).
use_case(file_level_mod, mpl_2_0).
use_case(copyleft_bypass, commercial).
use_case(open_source_redistribution, agpl_3_0).

% Compatibility matrix: compatible(LicenseA, LicenseB)
compatible(mpl_2_0, proprietary).
compatible(mpl_2_0, mpl_2_0).
compatible(bsl_1_1, source_available).
compatible(agpl_3_0, agpl_3_0).
compatible(commercial, proprietary).

% Select license based on use case query
select_license(UseCase, SelectedLicense) :-
    use_case(UseCase, SelectedLicense).

% Validate dependency compatibility
check_compatibility(License, DependencyType) :-
    compatible(License, DependencyType),
    format('~w is compatible with ~w.~n', [License, DependencyType]).

check_compatibility(License, DependencyType) :-
    \+ compatible(License, DependencyType),
    format('WARNING: ~w is INCOMPATIBLE with ~w.~n', [License, DependencyType]),
    fail.

% CLI Entrypoint handlers
main :-
    current_prolog_flag(argv, Argv),
    handle_args(Argv).

handle_args(['matrix']) :-
    write('=== LICENSE COMPATIBILITY MATRIX ===\n'),
    forall(compatible(A, B), format(' [OK] ~w <--> ~w\n', [A, B])),
    halt.

handle_args(['select', UseCase]) :-
    atom_string(UseCaseAtom, UseCase),
    ( select_license(UseCaseAtom, License)
    -> format('Recommended License: ~w\n', [License])
    ; format('Unknown use case: ~w\n', [UseCase])
    ),
    halt.

handle_args(['check', License, Dep]) :-
    atom_string(LicAtom, License),
    atom_string(DepAtom, Dep),
    check_compatibility(LicAtom, DepAtom),
    halt.

handle_args(_) :-
    write('Usage: swipl -q -t halt -f license_policy.pl -- [matrix | select <use_case> | check <license> <dep>]\n'),
    halt.
