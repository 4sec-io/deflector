#!/bin/bash
args=("$@")

echo "Deflector Control Script"
echo "First let's logon to Azure emergency account ()"  
az login

Create-WhatsappGroup() {
    # Create a new whatsapp group with the given name and members
    # $1 = group name
    # $2 = group members
    echo "Creating new whatsapp group $1 with members $2"
}

sendwhatsapp() {
    # Send a whatsapp message to the given group
    # $1 = group name
    # $2 = message
    echo "Sending whatsapp message to group $1 with message $2"
}

case $1 in
    "1")
        echo "Deflector Level 1"
        # Create a new Azure emergency admin account (az account admin ...) no CAP or MFA required use generic password and name
        az account admin create --name "EmergencyAdmin" --password "P@ssw0rd" --email "emergencyaad@xxxy.bbbbbby.be" --role "Owner"
        # autmatically cycle passwords of all current admin accounts and store generated password in Azure Key Vault
        az account admin cycle --all
        # create new whatsapp group with all emergency admins
        Create-WhatsappGroup -g "EmergencyAdmins" -m "Emergency Admins"
        # create whatsapp group with all cycled account admins
        Create-WhatsappGroup -g "CycledAdmins" -m "Cycled Admins"
        # send whatsapp message to all emergency admins with new password and account name
        sendwhatsapp -g "EmergencyAdmins" -m "New emergency admin account created with password P@ssw0rd"
        # send whatsapp message to all cycled account admins to inform them about the change and next steps
        sendwhatsapp -g "CycledAdmins" -m "Your account has been cycled, new password stored in Azure Key Vault"
        ###########################################################################################################################
        #                                                  IMPACT ANALYSIS                                                        #
        # 1. All current admin accounts will be password cycled                                                                   #
        # 2. All current admin accounts will be disabled                                                                          #
        # 3. All cycled admin accounts passwords will be stored in Azure Key Vault                                                #
        # 4. All current admin accounts will be replaced with new admin account                                                   #
        # 5. All current admin accounts will be sent to emergency admins via whatsapp message                                     #
        # 6. Production Services shall not be impacted                                                                            #
        ###########################################################################################################################
        ;;
    "2")
        echo "Deflector Level 2"
        # Lock down all public IP addresses => disable all
        az network public-ip list --query "[?ipAddress!=null].{Name:name,IP:ipAddress}" --output table | awk '{print $1}' | xargs -I {} az network public-ip update --name {} --resource-group $rg --allocation-method Static --idle-timeout 0
        # Lock down NSG => block external access to all VMs or services
        az network nsg rule create --name "DenyAllInbound" --nsg-name $nsg --resource-group $rg --priority 100 --source-address-prefixes "*" --source-port-ranges "*" --destination-address-prefixes "*" --destination-port-ranges "*" --access Deny --protocol "*" --direction Inbound
        # Lock down firewalls (all external access except backup VPN)
        f5cli -c "tmsh modify sys global-settings gui-setup disabled"
        fortigatecli -c "config system global; set admin-ssh disable; set admin-web disable; end"
        paloaltocli -c "configure; set deviceconfig system service disable-telnet yes; set deviceconfig system service disable-http yes; set deviceconfig system service disable-https yes; commit"
        # Establish a new VPN connection to On-Premises with backup admin only VPN
        openvpn --config backup.ovpn --daemon --auth-user-pass backup.auth --auth-nocache --remote-cert-tls server --pull
        # Lock down VPNs only leave backup vpn active
        ssh paloalto1 -c "configure; set network vpn ipsec ike gateway AzureVPN dead-peer-detection action clear; commit"
        ###########################################################################################################################
        #                                                  IMPACT ANALYSIS                                                        #
        # 1. All public IP addresses will be disabled                                                                             #
        # 2. All NSG rules will be updated to block all inbound traffic                                                           #
        # 3. All firewalls will be disabled except backup VPN                                                                     #
        # 4. New VPN connection will be established to On-Premises with backup admin only VPN                                     #
        # 5. All VPNs will be disabled except backup VPN                                                                          #
        # 6. Production Services shall not be impacted                                                                            #
        ###########################################################################################################################
        ;;
    "3")
        echo "Deflector Level 3"
        # Lock down all Azure VMs
        az vm list --query "[?powerState=='VM running'].{Name:name,ResourceGroup:resourceGroup}" --output table | awk '{print $1}' | xargs -I {} az vm stop --name {} --resource-group {}
        # Create new Dynamics 365 emergency admin account
        az ad user create --display-name "Dynamics 365 Admin" --password "P@ssw0rd" --user-principal-name "d365_emergency" --force-change-password-next-login true
        # Create new whatsapp group with all Dynamics 365 emergency admins
        Create-WhatsappGroup -g "Dynamics365Admins" -m "Dynamics 365 Admins"
        # Send whatsapp message to all Dynamics365 emergency admins with new password and account name
        sendwhatsapp -g "Dynamics365Admins" -m "New Dynamics 365 emergency admin account created with password P@ssw0rd"
        # Revove all dynamics 365 admin accounts
        az ad user list --query "[?startswith(userPrincipalName, 'd365')].{Name:userPrincipalName}" --output table | awk '{print $1}' | xargs -I {} az ad user delete --upn-or-object-id {}
        ###########################################################################################################################
        #                                                  IMPACT ANALYSIS                                                        #
        # 1. All Azure VMs will be stopped                                                                                        #
        # 2. New Dynamics 365 emergency admin account will be created with password P@ssw0rd                                      #
        # 3. New whatsapp group will be created with all Dynamics 365 emergency admins                                            #
        # 4. New whatsapp message will be sent to all Dynamics 365 emergency admins with new password and account name            #
        # 5. All current Dynamics 365 admin accounts will be removed                                                              #
        # 6. Production Services shall not be impacted                                                                            #
        ###########################################################################################################################
        ;;
    "4")
        echo "Deflector Level 4"
        ;;
    "5")
        echo "Deflector Level 5"
        ;;
    *)
        echo "Usage: $0 {1|2|3|4|5}"
        exit 1
        ;;
esac

