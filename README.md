# udrs
    spoke1  toSpoke2    10.2.0.0/16     Virtual appliance   10.0.0.4
    spoke2  toSpoke1    10.1.0.0/16     Virtual appliance   10.0.0.4

# hub-spokes-centos
spoke1 -- peering -- hub -- spoke2 -- 
# trafico hacia
tcpdump -i eth0 host 10.2.0.4

# iptables
# tiene 3 tablas
## tabla nat
### PREROUTING: Permite modificar paquetes entrantes antes de que se tome una decisión de enrutamiento.
### OUTPUT: Permite modificar paquetes generados por el propio equipo después de enrutarlos
### POSTROUTING: Permite modificar paquetes justo antes de que salgan del equipo.
## tabla filter
## tabla mangle

# veo las reglas
iptables -nvL

# borro una regla
iptables -D INPUT -p icmp -j ACCEPT

# permito icmp
iptables -A INPUT -p icmp -j ACCEPT

# configurar iptables como router
# https://www.linode.com/docs/guides/linux-router-and-ip-forwarding/?tabs=iptables

# miro las rutas
sudo iptables -S

sudo iptables -F
sudo iptables -X
sudo iptables -t nat -F
sudo iptables -t nat -X
sudo iptables -t mangle -F
sudo iptables -t mangle -X
sudo iptables -P INPUT ACCEPT
sudo iptables -P OUTPUT ACCEPT
sudo iptables -P FORWARD ACCEPT

sudo iptables -A FORWARD -j ACCEPT

# snat
## SNAT, la IP del router es estática 
## MASQUERADING, la IP del router es pública
# https://albertomolina.wordpress.com/2009/01/09/nat-con-iptables/
# todos los paquetes de vnet spoke1 ( 10.1.0.0/16) salen con la IP de eth0 de vmhub
iptables -t nat -A POSTROUTING -s 10.1.0.0/16 -o eth0 -j MASQUERADE