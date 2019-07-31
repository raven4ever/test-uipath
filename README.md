# Test SRE

Avem o aplicatie web ASP .NET Core 2.2, al carei pachet il poti gasi aici: https://uipathdevtest.blob.core.windows.net/binaries/netcoreapp2.2.zip . Este un sample app oferit de dezvoltatorii .NET Core care afiseaza o lista de URL-uri (localhost:5000, localhost:5001, etc).
Aceasta aplicatie trebuie deploy-ata pe doua VM-uri Ubuntu in Azure aflate in doua regiuni diferite (primary region West Europe si secondary location North Europe). Aceste VM-uri trebuie sa fie plasate in spatele unui Azure Traffic Manager care sa faca failover pe endpoint-ul VM-ului din regiunea secundara in caz ca cel din regiunea primara este down (gasesti mai multe detalii ale acestui pattern aici: https://docs.microsoft.com/en-us/azure/traffic-manager/traffic-manager-routing-methods#priority) 

Cerinte:
    - Folosing Terraform, provizioneaza infrastructura necesara acestui sistem (VM-uri, Traffic Manager)
    - Folosind Ansible, pe VM-uri, download-eaza zip-ul cu aplicatia web si configureaz-o sa ruleze in spatele unui Nginx reverse proxy care sa redirecteze traficul de pe portul 80 la portul 5000 (acolo unde asculta aplicatia). Aplicatia trebuie sa functioneze si dupa ce se restarteaza VM-ul
    - In final, va trebui sa adaugi o alerta pe traffic manager care sa trimita un mail in momentul in care endpoint-ul primary este down

Observatii:
    - VM-urile trebuie sa fie facute dupa imaginea Ubuntu Server 18.04 de la Canonical
    - VM-urile trebuie sa aiba size-ul Standard D2s v3
    - VM-urile trebuie sa aiba IP-uri publice atasate, cu DNS labels
    - Foloseste un password generator pentru parolele VM-urilor
    - Aplicatia are nevoie ca runtime-ul de .NET Core 2.2 sa fie instalat pe sistemul de operare unde ruleaza
    - Pentru a rula aplicatia, desfa zip-ul si ruleaza “dotnet MvcSample.dll”