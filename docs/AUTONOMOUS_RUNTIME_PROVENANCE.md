# Autonomous runtime provenance

The autonomous session director, temporal memory model, ensemble arbitration,
interest preflight, generated DSP graph model, graph mutation policy, renderer,
continuation state, and app integration in this repository were implemented
from the repository's behavioral specification and existing repository-owned
musical and DSP interfaces.

No third-party implementation source, assets, identifiers, constants, tests,
architectural expression, sample, binary, submodule, or new dependency were
inspected or incorporated for this implementation. `Package.swift` retains its
existing dependency set. The generated topology uses only modules implemented
inside `AutoTechnoDSP`; it does not load plug-ins or executable graph content.

The former Persistent V3 and 96-bar paths remain available to offline reference
executables and regression tests. The shipped `AutoTechnoApp` contains no
selection path to either runtime.
