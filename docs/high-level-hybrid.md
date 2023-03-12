@startuml
!theme carbon-gray
autonumber

Provisioner <- Gateway : Register request

group Repeated calls [n calls in k seconds]
Client -> Gateway : Call f(x)
end

Client -> Gateway : Call f(x)

Gateway -> Provisioner : Who should run f(x)?

Provisioner -> Gateway : Service

Gateway -> Service : Call op(x)

Service -> Gateway : Result of op(x)

Gateway -> Client : Result of f(x)

group Low load [below n calls in k seconds]
Provisioner -> Service : stop
end

@enduml
