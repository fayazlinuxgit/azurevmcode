provider "azurerm" {

features {} 

} 

#create resource group
resource "azurerm_resource_group" "fayaz-res-group" {
  
  name     = var.rsg_name
  location = "West Europe"
 
 tags = {
   "name" = "test-rs"
 }
}

data "local_file" "foo" {
    filename = "${path.module}/foo.txt"
}

#create virtual netwokr 
resource "azurerm_virtual_network" "fayaz-net" {
  name                = var.virtual_network_name
  resource_group_name = azurerm_resource_group.fayaz-res-group.name
  location            = azurerm_resource_group.fayaz-res-group.location
  address_space       = ["10.0.0.0/16"]
}

# Create subnet
resource "azurerm_subnet" "fayaz-subnet" {
  name                 = var.subnet-name
  resource_group_name  = azurerm_resource_group.fayaz-res-group.name
  virtual_network_name = azurerm_virtual_network.fayaz-net.name
  address_prefixes     = ["10.0.1.0/24"]
}

output "f" {
  value     = data.local_file.foo
  
}


#crate public ip
resource "azurerm_public_ip" "pub-ip" {
  name                = "myPublicIP"
  location            = azurerm_resource_group.fayaz-res-group.location
  resource_group_name = azurerm_resource_group.fayaz-res-group.name
  allocation_method   = "Dynamic"
  
}

#create network SG
resource "azurerm_network_security_group" "mySG" {
  name                = var.SG-Name
  location            = azurerm_resource_group.fayaz-res-group.location
  resource_group_name = azurerm_resource_group.fayaz-res-group.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create network interface
resource "azurerm_network_interface" "fayazint" {
  name                = var.networkint-name
  location            = azurerm_resource_group.fayaz-res-group.location
  resource_group_name = azurerm_resource_group.fayaz-res-group.name

  ip_configuration {
    name                          = "myNicConfiguration"
    subnet_id                     = azurerm_subnet.fayaz-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pub-ip.id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "sgtonic" {
  network_interface_id      = azurerm_network_interface.fayazint.id
  network_security_group_id = azurerm_network_security_group.mySG.id
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.fayaz-res-group.name
  }

  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
  name                     = "diag${random_id.randomId.hex}"
  location                 = azurerm_resource_group.fayaz-res-group.location
  resource_group_name      = azurerm_resource_group.fayaz-res-group.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}



# Create (and display) an SSH key
resource "tls_private_key" "fayaz_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content         = tls_private_key.fayaz_ssh.private_key_pem
  filename        = "key.pem"
  file_permission = "0600"
}


# Create virtual machine
resource "azurerm_linux_virtual_machine" "myvm-test" {
  name                  = var.vm-name-azureportal
  location              = azurerm_resource_group.fayaz-res-group.location
  resource_group_name   = azurerm_resource_group.fayaz-res-group.name
  network_interface_ids = [azurerm_network_interface.fayazint.id]
  #size                  = "Standard_DS1_v2"
  #size                  = "Standard_D2as_v5"
  #size                   = var.size
  size   =  "Standard_D2_v2"
  os_disk {
    name                 = "myOsDisk"
    caching              = "ReadWrite"
   # storage_account_type = "Premium_LRS"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  
  computer_name                   = var.computer_name
  admin_username                  = "azureuser"
  disable_password_authentication = true

  

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.fayaz_ssh.public_key_openssh
  }


  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
  }
  tags = {
    environment = var.vm-tag
  }
}







