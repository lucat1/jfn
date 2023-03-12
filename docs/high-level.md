@startuml
!theme carbon-gray
autonumber

Provisioner <- Gateway : Register request

Provisioner <- Runner : Register request

Provisioner -> Gateway : New Runner

Client -> Gateway : Call f(x)

Gateway -> Provisioner : Who should run f(x)?

Provisioner -> Gateway : Runner

Gateway -> Runner : Call f(x)

Runner -> Gateway : Result of f(x)

Gateway -> Client : Result of f(x)

Runner -> Provisioner: Unregister

Provisioner -> Gateway : Unregister runner
@enduml
