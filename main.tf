provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "myAzure"
  location = "northeurope"
}


## hub ##
resource "azurerm_virtual_network" "hubvnet" {
  name                = "hubvnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]

}

resource "azurerm_subnet" "hubsubnet" {
  name                 = "hubsubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.hubvnet.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_public_ip" "hubvm_public_ip" {
  name                = "hubvm_public_ip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Dynamic"
}
resource "azurerm_network_interface" "hubvmnic" {
  name                 = "hubvmnic"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  enable_ip_forwarding = true
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.hubsubnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.0.4"
    public_ip_address_id          = azurerm_public_ip.hubvm_public_ip.id
  }
}

resource "azurerm_linux_virtual_machine" "hubvm" {
  name                            = "hubvm"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  size                            = "Standard_B2s"
  disable_password_authentication = false
  admin_username                  = "jose"
  admin_password                  = "Qazxsw23edcvfr45-."
  network_interface_ids = [
    azurerm_network_interface.hubvmnic.id,
  ]



  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "OpenLogic" # "Canonical"
    offer     = "CentOS"    # "0001-com-ubuntu-server-jammy"
    sku       = "8_5-gen2"  # "22_04-lts"
    version   = "latest"
  }


  connection {
    type     = "ssh"
    user     = "jose"
    password = "Qazxsw23edcvfr45-."
    host     = self.public_ip_address
  }

  provisioner "remote-exec" {
    inline = ["sudo sysctl -w net.ipv4.ip_forward=1",
      "sudo yum install iptables-services",
      "sudo sudo systemctl start iptables",
      "sudo iptables -S",
      "sudo iptables -F",
      "sudo iptables -X",
      "sudo iptables -t nat -F",
      "sudo iptables -t nat -X",
      "sudo iptables -t mangle -F",
      "sudo iptables -t mangle -X",
      "sudo iptables -P INPUT ACCEPT",
      "sudo iptables -P OUTPUT ACCEPT",
      "sudo iptables -P FORWARD ACCEPT",
      "sudo iptables -t nat -A POSTROUTING -s 10.1.0.0/16 -o eth0 -j MASQUERADE"
    ]
  }
  // sysctl -a | grep net.ipv4.ip_forward
}

## spoke 1 ##
resource "azurerm_virtual_network" "spoke1vnet" {
  name                = "spoke1vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.1.0.0/16"]

}

resource "azurerm_subnet" "spoke1subnet" {
  name                 = "spoke1subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.spoke1vnet.name
  address_prefixes     = ["10.1.0.0/24"]
}

resource "azurerm_route_table" "udrsubnetspoke1subnet" {
  name                          = "udrsubnetspoke1subnet"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  disable_bgp_route_propagation = false

  route {
    name                   = "toSpoke2"
    address_prefix         = "10.2.0.0/16"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.0.0.4"
  }

}

resource "azurerm_subnet_route_table_association" "udersubnetspoke1" {
  subnet_id      = azurerm_subnet.spoke1subnet.id
  route_table_id = azurerm_route_table.udrsubnetspoke1subnet.id
}

resource "azurerm_public_ip" "spoke1_public_ip" {
  name                = "spoke1_public_ip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Dynamic"
}
resource "azurerm_network_interface" "spoke1vmnic" {
  name                 = "spoke1vmnic"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  enable_ip_forwarding = true
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.spoke1subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.1.0.4"
    public_ip_address_id          = azurerm_public_ip.spoke1_public_ip.id
  }
}

resource "azurerm_linux_virtual_machine" "spoke1vm" {
  name                            = "spoke1vm"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  size                            = "Standard_B2s"
  disable_password_authentication = false
  admin_username                  = "jose"
  admin_password                  = "Qazxsw23edcvfr45-."
  network_interface_ids = [
    azurerm_network_interface.spoke1vmnic.id,
  ]



  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "OpenLogic" # "Canonical"
    offer     = "CentOS"    # "0001-com-ubuntu-server-jammy"
    sku       = "8_5-gen2"  # "22_04-lts"
    version   = "latest"
  }



}

## spoke 2 ##

resource "azurerm_virtual_network" "spoke2vnet" {
  name                = "spoke2vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.2.0.0/16"]
}


resource "azurerm_subnet" "spoke2subnet" {
  name                 = "spoke2subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.spoke2vnet.name
  address_prefixes     = ["10.2.0.0/24"]
}
resource "azurerm_route_table" "udrsubnetspoke2subnet" {
  name                          = "udrsubnetspoke2subnet"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  disable_bgp_route_propagation = false

  route {
    name                   = "toSpoke1"
    address_prefix         = "10.1.0.0/16"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.0.0.4"
  }

}

resource "azurerm_subnet_route_table_association" "udersubnetspoke2" {
  subnet_id      = azurerm_subnet.spoke2subnet.id
  route_table_id = azurerm_route_table.udrsubnetspoke2subnet.id
}
resource "azurerm_public_ip" "spoke2_public_ip" {
  name                = "spoke2_public_ip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Dynamic"
}
resource "azurerm_network_interface" "spoke2vmnic" {
  name                 = "spoke2vmnic"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  enable_ip_forwarding = true
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.spoke2subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.2.0.4"
    public_ip_address_id          = azurerm_public_ip.spoke2_public_ip.id
  }
}

resource "azurerm_linux_virtual_machine" "spoke2vm" {
  name                            = "spoke2vm"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  size                            = "Standard_B2s"
  disable_password_authentication = false
  admin_username                  = "jose"
  admin_password                  = "Qazxsw23edcvfr45-."
  network_interface_ids = [
    azurerm_network_interface.spoke2vmnic.id,
  ]



  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "OpenLogic" # "Canonical"
    offer     = "CentOS"    # "0001-com-ubuntu-server-jammy"
    sku       = "8_5-gen2"  # "22_04-lts"
    version   = "latest"
  }

}

## peerings
resource "azurerm_virtual_network_peering" "hub-spoke1" {
  name                         = "hub-spoke1"
  resource_group_name          = azurerm_resource_group.rg.name
  virtual_network_name         = azurerm_virtual_network.hubvnet.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke1vnet.id
  allow_forwarded_traffic      = true
  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "spoke1-hub" {
  name                         = "spoke1-hub"
  resource_group_name          = azurerm_resource_group.rg.name
  virtual_network_name         = azurerm_virtual_network.spoke1vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.hubvnet.id
  allow_forwarded_traffic      = true
  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "hub-spoke2" {
  name                         = "hub-spoke2"
  resource_group_name          = azurerm_resource_group.rg.name
  virtual_network_name         = azurerm_virtual_network.hubvnet.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke2vnet.id
  allow_forwarded_traffic      = true
  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "spoke2-hub" {
  name                         = "spoke2-hub"
  resource_group_name          = azurerm_resource_group.rg.name
  virtual_network_name         = azurerm_virtual_network.spoke2vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.hubvnet.id
  allow_forwarded_traffic      = true
  allow_virtual_network_access = true
}

