# SUSE Linux Micro 6.2: offline ISO s VMware Tools

Datum overeni zdroju: 2026-10-08.

## 1. Zadani a rozhodnuti

- Cilovy system: SUSE Linux Micro 6.2, x86_64.
- Cilova platforma: VMware vSphere / ESXi; konkretni verze zatim neni znama.
- Vstup: oficialni definice image Micro 6.2 a pripadne referencni self-install ISO.
- Pozadovany vystup: vlastni bootovatelne self-install ISO.
- VMware Tools musi byt primo v instalovanem systemu.
- Instalace a prvni spusteni musi fungovat bez internetu.
- VMDK ani VMware sablona nejsou pozadovanym primarnim vystupem.
- Build ani test na ESXi zatim nebyl proveden.

Pro Linux pouzijeme distribucni balicek `open-vm-tools`, nikoli stary
instalator VMware Tools z pripojeneho CD. SUSE jej uvadi v konfiguraci
nasazeni Micro 6.2 na vSphere [2].

Pouhe pridani RPM souboru na puvodni ISO nezajisti jejich instalaci.
Self-install medium nasazuje pripraveny systemovy image; balicky proto
musime instalovat do tohoto image pred vytvorenim vysledneho ISO.

## 2. Zaver k air-gap CD / DVD / ISO

**Ano: SUSE nabizi oficialni Packages ISO pro air-gap nasazeni Micro 6.2.
Obsahuje i VMware Tools a solver overil jejich zavislosti pouze proti tomuto
mediu. Uplnost pro cely KIWI build jeste neni overena.**

Puvodni informace zadavatele o chybejicich Tools na Packages ISO byla
vyvracena primou kontrolou stazeneho oficialniho media na x86_64 Ubuntu.
ISO obsahuje `open-vm-tools` i `libvmtools0` 13.0.0-160000.2.2.
Samostatny repozitar s kandidaty 13.1.0 proto pro vychozi GM build
nepotrebujeme. Podrobnosti overeni jsou v sekci 9.

Existence, nazev, velikost a kontrolni soucet byly overeny primo
v metadatech oficialniho download portalu [5, 6]:

| Medium | Ucel | Velikost v bajtech |
| --- | --- | ---: |
| `SL-Micro-Packages-6.2-x86_64-GM.iso` | Nebootovatelne balickove medium pro air-gap | 2240700416 |
| `SL-Micro.x86_64-6.2-Default-SelfInstall-GM.install.iso` | Referencni bootovatelne self-install medium | 1631275008 |

SHA-256 Packages ISO:

```text
0d9abdf54056c06c3c01299c7997f03bcab19482ed03d6ea8960b8dce8f83bed
```

SHA-256 uvedeneho referencniho Default SelfInstall ISO:

```text
c01847cee7f454b0b8f8a6288e2c608d8d66d216cba8cf9ccad45f44ea045a8a
```

Pred pouzitim znovu porovnat soucet se SUSE portalem pro konkretni soubor.
Nestahovat variantu `-Source.iso`: obsahuje zdrojove balicky, nikoli
pozadovane binarni RPM.

### Co je overene a co jeste ne

- Overeno: SUSE oznacuje Packages ISO jako
  "Non-bootable packages ISO (for air-gap deployment)" [6].
- Overeno: existuje varianta pro Micro 6.2 x86_64 s vyse uvedenym nazvem.
- Overeno primo: Packages ISO obsahuje 1178 RPM, vcetne
  `open-vm-tools` a `libvmtools0` 13.0.0-160000.2.2.
- Overeno: SHA-256 ISO souhlasi s portalem, podpisy obou Tools RPM jsou
  platne a zavislosti Tools jsou resitelne pouze z tohoto ISO.
- Nalezeny kandidat: `open-vm-tools` 13.1.0 z navazujiciho projektu
  SUSE SLFO 1.2 (podrobnosti v sekci 8).
  RPM podpisy, produktova podpora a uplnost zavislosti zatim nejsou overeny.
- Neovereno: zda medium samo pokryje vsechny balicky z oficialni KIWI
  definice, vcetne pripadneho samostatneho boot/install image.
- Neovereno: zda medium obsahuje vsechny nastroje pro pripravu build VM.
  Balicky ciloveho systemu a zavislosti build prostredi nejsou totez.
- Puvodni pokus o anonymni nacteni predpokladaneho SBOM vratil HTTP 403.
  Nasledne bylo stazeno a primo prohledano samotne ISO.
- Nelze zatim tvrdit, ze obsahuje "vsechny baliky" ze vsech SUSE produktu,
  modulu a aktualizacnich kanalu.

GM medium je pevny snapshot. Nelze predpokladat, ze obsahuje pozdejsi
bezpecnostni aktualizace. Pro aktualizovany offline image bude potreba
samostatne dodat odpovidajici aktualizacni RPM nebo mirror repozitaru.

Velikost je priblizne 2,24 GB (2,09 GiB), tedy vice nez kapacita bezneho CD.
Pouzijeme virtualni ISO pripojene jako CD/DVD v ESXi, fyzicke DVD,
nebo read-only pripojeny obsah ISO na build VM.

### Jak zapojime Packages ISO

```text
Oficialni KIWI definice Micro 6.2
                +
Packages ISO jako lokalni zdroj RPM
                +
open-vm-tools a zavislosti z Packages ISO
                +
Konfigurace sluzeb
                |
                v
      Systemovy image pres KIWI
                |
                v
     Vlastni self-install ISO
                |
                v
  Offline instalace a test na ESXi
```

Packages ISO samo neni instalacni medium a jeho pouhe pripojeni k cilove
VM nenainstaluje Tools automaticky. Pri doporucene variante bude pouzito
pri buildu; pri cilove instalaci uz druhe medium nebude potreba.

Offline instalace nemusi vyzadovat online registraci. To vsak nenahrazuje
opravneni k pouziti SUSE produktu, podminky subscription ani pravidla
redistribuce vlastniho image. Pristup k online aktualizacim je samostatna vec.

## 3. Plan realizace

### Faze A: overit podklady a balicky

1. Zjistit presnou verzi ESXi a vCenter a overit podporu hostovaneho OS.
2. Zvolit profil Base nebo Default a firmware VM, zejmena UEFI / Secure Boot.
   Pro zacatek pouzit standardni kernel; RT pouze pokud je pozadovan.
3. Stahnout Packages ISO a pripadne referencni self-install ISO ze SUSE.
4. Overit kontrolni soucty a dostupne podpisy.
5. Na Linuxove VM pripojit Packages ISO read-only.
6. Prohledat RPM, zjistit verzi `open-vm-tools` a umisteni repozitarovych metadat.
7. Overit, zda referencni systemovy image uz Tools neobsahuje.
8. Vyresit zavislosti proti lokalnimu mediu bez pristupu k online repozitarum.

Historicky jsme kvuli informaci o chybejicich Tools planovali nejprve najit
oficialni zdroj `open-vm-tools` kompatibilni s Micro 6.2 a overit jeho
podporovatelnost. Priklad ve vSphere dokumentaci [2] sam o sobe nedokazuje,
ze balicek obsahuje konkretni medium nebo dostupny repozitar.
Na pripojene Linuxove x86_64 VM vyresit a stahnout balicek i chybejici
zavislosti proti odpovidajicimu zakladu Micro 6.2. Overit RPM podpisy,
ulozit verze a pripravit samostatny lokalni repozitar pro KIWI.
Pokud vhodny oficialni zdroj nebude dostupny, zastavit tento krok
a vyjasnit dostupnost se SUSE; nenahrazovat jej nahodnym RPM z jine distribuce.
Tato doplnkova cesta uz neni nutna pro GM variantu: Tools a jejich
zavislosti byly nalezeny a solverem overeny primo na Packages ISO (sekce 9).

Ilustracni prikazy pro Linuxovou VM, nikoli prikazy provedene v teto relaci:

```bash
sha256sum SL-Micro-Packages-6.2-x86_64-GM.iso
sudo mkdir -p /mnt/micro-packages
sudo mount -o loop,ro SL-Micro-Packages-6.2-x86_64-GM.iso /mnt/micro-packages
find /mnt/micro-packages -type f -name 'open-vm-tools*.rpm'
find /mnt/micro-packages -type f -name repomd.xml
```

Presnou cestu repozitare zjistit z obsahu media, nikoli ji odhadnout.
Pokud je repozitaru vice, overit vsechny relevantni cesty.
Pritomnost jednoho RPM jeste nedokazuje uplnost jeho zavislosti.

**Vystup:** seznam dostupnych balicku, verzi a chybejicich zavislosti.

### Faze B: pripravit build prostredi

1. Pouzit samostatnou Linuxovou build VM x86_64 s dostatkem disku.
   Nesestavovat primo na produkcnim ESXi hostiteli.
2. Zprovoznit kompatibilni KIWI NG podle dokumentace SUSE [3].
3. Ziskat oficialni definici z projektu
   `SUSE:SLFO:Products:SL-Micro:6.2`, balicek `SL-Micro` [4].
4. Zaznamenat revizi definice a verze build nastroju.
5. Nahradit odpovidajici online zdroje lokalnimi repozitari z Packages ISO.
6. Proverit zdroje vsech pouzitych profilu a boot/install definic.
7. Pokud musi byt offline i build, predem dodat KIWI, jeho zavislosti,
   definice, pripadne boot komponenty a pripadny build kontejner.

Je treba odlisit:

- **Offline cilovou instalaci:** build muze mit internet.
- **Plne air-gap build:** build nesmi nic stahovat; Packages ISO samo
  nemusi stacit pro pripravu build prostredi.

Pokud medium nepokryje build, pripravit verifikovany lokalni mirror nebo
chybejici balicky z odpovidajicich oficialnich repozitaru. Nemichat RPM
z jine verze SUSE ani z openSUSE Leap Micro.

**Vystup:** pripravena build VM a dostupne vsechny zdroje sestaveni.

### Faze C: upravit cilovy image

1. Do seznamu balicku ciloveho systemu doplnit `open-vm-tools`.
2. Overit dodane systemd jednotky a zajistit start `vmtoolsd.service`.
   Dalsi jednotky zapnout jen podle skutecneho balicku a pozadovanych funkci.
3. Tools instalovat do hostitelskeho OS, nikoli aplikacniho kontejneru.
4. Zachovat read-only root, Btrfs, snapshoty a transakcni aktualizace.
5. Zachovat potrebne ovladace disku a site pro ESXi; Tools je nenahrazuji.
6. Zachovat konfiguracni mechanismus prvniho startu Micro.
7. Nedoplnovat hesla, SSH privatni klice, subscription kody ani
   registracni identitu build stroje do vysledneho image.

Pri zmene beziciho Micro pouzivat `transactional-update`, ne bezne
`zypper install` proti read-only root [7]. Pri buildu postupovat podle
mechanismu KIWI; neprovadet ad hoc remount produkcniho root do read-write.

**Vystup:** upravena definice s minimalnimi zmenami oproti oficialnimu zakladu.

### Faze D: sestavit self-install ISO

1. Pouzit odpovidajici self-install/OEM profil z definice Micro.
2. Sestavit cilovy systemovy image s Tools.
3. Vytvorit bootovatelne instalacni ISO. KIWI pro OEM image podporuje
   `installiso="true"` [8]; presny profil a nastaveni overit v Micro definici.
4. Nevytvaret obecne live ISO misto pozadovaneho self-install media.
5. Ulozit build log, seznam RPM, revizi definice a SHA-256 vysledku.
6. Overit, ze image neobsahuje tajne udaje ani identitu build VM.
7. Pri pozadavku na Secure Boot overit podepsane boot komponenty a skutecny boot.

**Vystup:** vlastni ISO a metadata umoznujici dohledat jeho obsah.

### Faze E: overit offline instalaci na ESXi

Testovat pouze na nove VM s prazdnym testovacim diskem.
Self-install muze prepsat cilovy disk; nepripojovat produkcni disky.

1. Odpojit sitovou kartu VM.
2. Nainstalovat z vlastniho ISO bez Packages ISO jako druheho media.
3. Odpojit instalacni ISO a spustit system z disku.
4. Overit dostupnost balicku a stav sluzby:

   ```bash
   rpm -q open-vm-tools
   vmtoolsd --version
   systemctl is-enabled vmtoolsd.service
   systemctl is-active vmtoolsd.service
   journalctl -u vmtoolsd.service -b --no-pager
   ```

5. Ve vSphere overit, ze Tools bezi. Guest-managed oznaceni je
   pro distribucni `open-vm-tools` ocekavane.
6. Overit guest shutdown a restart z vSphere.
7. Znovu nabootovat a overit, ze Tools startuji automaticky.
8. Pripojit sit a overit komunikaci a reportovani IP do vSphere.
9. Overit zachovani read-only root a transakcniho mechanismu.
10. Pokud jsou pozadovany guest customization, quiesced zalohy nebo
    konkretni zalohovaci produkt, provest samostatne integracni testy.

**Akceptacni kriterium:** nova VM bez internetu a bez dalsiho balickoveho
media ma po instalaci funkcni Tools; startuji po rebootu a vSphere
dokaze korektne vypnout a restartovat guest OS.

Pokud ma byt offline i build, navic provest cely build s blokovanym
externim pristupem. Uspesny online build neni dukazem air-gap buildu.

## 4. Alternativy a jejich omezeni

| Varianta | Vhodnost pro zadani |
| --- | --- |
| Vlastni KIWI self-install ISO | Doporuceno; Tools jsou soucasti nasazeneho systemu |
| Puvodni ISO + Combustion + Packages ISO | Muze umoznit offline instalaci balicku pri prvnim startu, ale nesplnuje pozadavek na Tools uvnitr jedineho instalacniho ISO bez dalsi pripravy |
| ISO instalace + rucni transactional instalace z Packages ISO | Vhodne pro overeni balicku, nikoli konecny automaticky vystup |
| VMware sablona nebo VMDK s Tools | Mozna alternativa pro hromadne nasazeni, neni vybranym vystupem |
| Pouhe pridani RPM na instalacni ISO | Nedostatecne; RPM se tim nenainstaluji do ciloveho systemu |

Combustion bezi pri prvnim startu v transakcnim prostredi a umi instalovat
balicky [1]. Online prvni start ani registrace nejsou nasim zvolenym resenim.

## 5. Co potrebujeme od zadavatele

- Presnou verzi ESXi a pripadne vCenter.
- Packages ISO, pripadne jeho overeny seznam balicku / SBOM.
- Pro vychozi GM build pouzit Tools primo z overeneho Packages ISO.
  Pristup k dalsimu zdroji je potreba pouze pro balicky chybejici pri
  kompletnim buildu nebo pro pozdejsi aktualizace.
- Pristup k Linuxove build VM a testovaci VM na ESXi.
- Rozhodnuti, zda musi byt offline pouze instalace, nebo i samotny build.
- Pozadavek na Base vs. Default, Secure Boot a pripadne guest customization / zalohy.
- Potvrzeni opravneni k pouziti SUSE medii; pro aktualizace pristup
  k subscription nebo internimu mirroru.

Puvodni self-install ISO je uzitecne jako reference, ale pri KIWI ceste
jsou zasadni definice image a dostupnost RPM. Pro dalsi overeni air-gap
varianty ma prioritu Packages ISO.

## 6. Stav a navazujici krok

Packages ISO bylo stazeno, overeno a pripojeno read-only na x86_64 VM.
Zavislosti Tools byly vyreseny v izolovanem dry-run prostredi.
Vlastni ISO nebylo sestaveno a VMware test nebyl proveden.

**Dalsi krok:** zprovoznit kompatibilni KIWI NG 10.x na x86_64 VM,
nahradit OBS zdroj lokalnim repozitarem z ISO a overit kompletni build
jednoho z profilu Base-SelfInstall / Default-SelfInstall.

## 7. Zdroje

1. [SUSE Micro 6.2: deployment ze self-install ISO a Combustion](https://documentation.suse.com/sle-micro/6.2/html/Micro-deployment-selfinstall-images/index.html)
2. [SUSE Micro 6.2: vSphere / VMDK; priklad instalace open-vm-tools](https://documentation.suse.com/sle-micro/6.2/html/Micro-deployment-vmdk/index.html)
3. [SUSE Micro 6.2: customizace a build pres KIWI NG](https://documentation.suse.com/sle-micro/6.2/html/Micro-developers-guide/index.html)
4. [Oficialni build projekt Micro 6.2](https://build.opensuse.org/project/show/SUSE:SLFO:Products:SL-Micro:6.2)
5. [SUSE download portal](https://www.suse.com/download/sle-micro/)
6. [Metadata download portalu pro Micro 6.2 x86_64](https://www.suse.com/download/ajax/2913/)
7. [SUSE Micro 6.2: transactional-update](https://documentation.suse.com/sle-micro/6.2/html/Micro-transactional-updates/index.html)
8. [KIWI: typy image, OEM a installiso](https://osinside.github.io/kiwi/image_types_and_results.html)
9. [SUSE Micro 6.2: release notes](https://documentation.suse.com/releasenotes/sle-micro/html/releasenotes_sle-micro_6.2/index.html)

Odkazy na stazeni generovane SUSE mohou byt docasne podepsane.
Do tohoto dokumentu nejsou ukladany autentizacni parametry ani pristupove tokeny.

## 8. Skutecne provedena priprava na Macu

Prostredi: macOS na Apple Silicon (`arm64`). Pouzity pouze existujici
nastroje `curl`, `shasum`, `patch`, `xmllint`, Bash a `bsdtar`.
Nebyl nainstalovan zadny novy nastroj a nebyl spusten zadny RPM ani build
skript stazeny ze SUSE. U `config.sh` byla provedena pouze kontrola syntaxe.

### 8.1 Oficialni definice a duvod chybejicich Tools v self-install profilu

Byly stazeny nezmenene soubory oficialniho balicku `SL-Micro` do
[upstream/SL-Micro-6.2](./upstream/SL-Micro-6.2/), vcetne licence.

- OBS projekt: `SUSE:SLFO:Products:SL-Micro:6.2`.
- Revize: `24`.
- Source MD5 identifikator revize: `f20fd430845c88fcda62d025b7ac6631`.
- [Listing zdroju ulozeny lokalne](./upstream/SL-Micro-6.2-source.xml).
- [Metadata projektu ulozena lokalne](./upstream/SL-Micro-6.2-project.xml).
- [SHA-256 stazenych zdroju](./upstream/SHA256SUMS).
- [Verejny zdrojovy endpoint s pevnou revizi](https://api.opensuse.org/public/source/SUSE:SLFO:Products:SL-Micro:6.2/SL-Micro?rev=f20fd430845c88fcda62d025b7ac6631).

V [SL-Micro.kiwi](./upstream/SL-Micro-6.2/SL-Micro.kiwi) je balicek
`open-vm-tools` explicitne pridan pouze v bloku `profiles="x86-vmware"`.
Profily `Default-SelfInstall` a `Base-SelfInstall` pro x86_64 naopak
vyzaduji `x86-self_install`, nikoli `x86-vmware`.
To vysvetluje rozdil v explicitnim vyberu balicku mezi VMDK a ISO.
Obsah konkretniho vydaneho ISO ani implicitni zavislosti tim nejsou overeny.

Self-install preference uz obsahuji OEM typ, `installiso="true"`,
UEFI, Btrfs a read-only root snapshot. Tyto vlastnosti neni potreba
vymyslet znovu ani menit pro samotne pridani Tools.

Definice pouziva zdroj `obsrepositories:/`. To je zdroj urceny pro OBS,
nikoli hotova cesta k lokalnimu ISO. Pred lokalnim KIWI buildem jej
musime nahradit overenymi lokalnimi repozitari.

### 8.2 Nalezeny a stazeny RPM kandidat

Metadata Micro projektu odkazuji na projekt `SUSE:SLFO:1.2`, repozitar
`standard`. V tomto navazujicim projektu byly nalezeny zdroje i binarni
balicky `open-vm-tools`.

- [Verejny listing binarnich balicku](https://api.opensuse.org/public/build/SUSE:SLFO:1.2/standard/x86_64/open-vm-tools).
- [Lokalni kopie listingu](./tools-source/binaries.xml).
- Revize zdroju balicku: `4`.
- Source MD5 identifikator: `1022713899c17af2ef74652258dad48f`.
- [Lokalni kopie zdrojoveho listingu](./tools-source/source.xml).
- [RPM spec](./tools-source/open-vm-tools.spec) a systemd jednotky jsou
  ulozeny v [tools-source](./tools-source/).

Stazene kandidaty jsou ulozeny v `packages/candidates/` a ignorovany Gitem:

| RPM | SHA-256 vypocteny po stazeni |
| --- | --- |
| `open-vm-tools-13.1.0-160000.1.1.x86_64.rpm` | `1dc07040bc984b1bfc07fb25b745c95b61f0a1d0f051a9e2bfbae8dc2d6197d9` |
| `libvmtools0-13.1.0-160000.1.1.x86_64.rpm` | `077fb2224b00e627229130d4776e87a764c24c89732bbcb92c5ccd423992d7c8` |

Balicky lze znovu stahnout pres vyse uvedeny binarni endpoint pripojenim
`/<nazev-RPM>`. Binarni endpoint neni pripnuty k source revizi, muze se menit.
Pro dohledatelnost konkretniho stazeneho souboru slouzi zaznamenany SHA-256.

**Jde o kandidaty z navazujiciho SUSE build projektu, nikoli o potvrzeni
podporovaneho instalacniho zdroje pro produkt Micro 6.2.**
Pro produkcni pouziti preferovat odpovidajici podepsany produktovy RPM
ze SUSE kanalu nebo si potvrdit tento zdroj se SUSE.
Samotny vypocteny SHA-256 neni overeni podpisu nebo duveryhodnosti balicku.
Aktualni verejna OBS revize a binarni build nemuseji odpovidat presnemu
GM snapshotu Packages ISO. Kompatibilitu s jeho knihovnami a verzemi
nelze odvodit pouze z nazvu navazujiciho projektu.

Na Macu byl pomoci `bsdtar` prohledan skutecny obsah RPM:

- Obsahuje `vmtoolsd.service` a `vgauthd.service`.
- `vmtoolsd.service` vyzaduje `vgauthd.service`.
- `Also=vgauthd.service` zajistuje zapnuti obou pri enable vmtoolsd.
- Jednotky pouzivaji `ConditionVirtualization=vmware`.
  Spusteni mimo VMware proto neni validni funkcni test.

RPM spec uvadi mj. zavislosti na odpovidajicim `libvmtools0`, `net-tools`,
`tar` a `which`. Dalsi zavislosti vznikaji automaticky z binarnich knihoven.
Tyto dva stazene RPM tedy **nejsou kompletnim offline repozitarem**.
Uplny seznam a reseni zavislosti vyzaduje Linux, RPM metadata a solver.

### 8.3 Pripravena minimalni uprava self-install image

[Patch](./patches/selfinstall-vmware-tools.patch) provadi pouze:

1. Rozsireni existujiciho Tools bloku na `x86-vmware,x86-self_install`.
2. Zapnuti `vmtoolsd.service` v `config.sh` pro `x86-self_install`.
   Chybejici jednotka zpusobi chybu buildu; neni potichu ignorovana.

Zmena je pro standardni x86_64 self-install profily
`Base-SelfInstall` a `Default-SelfInstall`; nemenime ARM, RT ani
ostatni platformy. Nevybirame oba vzajemne odlisne platformni profily
`x86-vmware` a `x86-self_install` najednou.
Definice take obsahuje ECS profil vyuzivajici `x86-self_install`;
pokud by se pouzil, obdrzi Tools rovnez. ECS neni cilem tohoto zadani.

[Pripravny skript](./scripts/prepare-image.sh) overuje SHA-256 dvou
menenych upstream souboru, kopiruje definici do vystupniho adresare,
aplikuje patch a kontroluje XML a Bash syntaxi.
Existujici vystup neprepise.

Z korene tohoto projektu:

```bash
bash scripts/prepare-image.sh
```

Jiz vytvoreny vystup je v `prepared/SL-Micro-6.2/`, ignorovanem Gitem.
Pro dalsi kopii pouzit novy adresar:

```bash
bash scripts/prepare-image.sh prepared/SL-Micro-6.2-next
```

**Vystup zatim neni pripraveny k buildu:** chybi lokalni repozitare,
overeni RPM podpisu, zavislosti a KIWI schema validace.
Skript neprovadi instalaci, build ani pripojeni ISO.
Puvodni upstream soubory zustavaji nezmenene.

Provedene kontroly prosly:

- SHA-256 stazenych zdroju a obou RPM souhlasi s lokalnimi manifesty.
- Patch byl aplikovan bez fuzzy prizpusobeni.
- Upraveny XML je syntakticky validni a obsahuje jediny odpovidajici Tools blok.
- Pripravny skript a upraveny `config.sh` prosly `bash -n`.
- Podminka pro zapnuti sluzby rozlisuje standardni x86 self-install od
  VMware, ARM, RT a podobne pojmenovanych profilu.
- Opakovane spusteni pripravneho skriptu spravne odmitlo prepsat vystup.
- VS Code pro pripravny skript a patch nehlasi diagnosticke chyby.

Tyto kontroly neoveruji RPM podpisy, KIWI schema ani chovani systemu za behu.

### 8.4 Co bylo blokovano po priprave na Macu

- Packages ISO zatim nebylo stazeno ani prohledano.
- Presne repozitarove cesty uvnitr ISO nejsou zname.
- Chybi overena sada zavislosti a potvrzeni produktoveho zdroje Tools.
- Neni provedena KIWI schema validace, build ani offline instalace.
- Chybi Linuxova x86_64 build VM a konkretni verze ESXi.

Priprava na Macu je tedy realny podklad pro dalsi krok, nikoli hotove ISO.
Tento historicky stav byl nasledne aktualizovan kontrolami v sekci 9.

## 9. Overeni na x86_64 Ubuntu v UTM

VM: `192.168.64.18`, uzivatel `jartas`, Ubuntu 24.04.5 LTS, x86_64,
8 GB RAM. Heslo neni ulozeno v projektovych souborech.
Podklady byly preneseny do `/home/jartas/micro-os`.
Prvni SSH klic byl prijat metodou trust-on-first-use na zadost zadavatele;
dalsi spojeni overuji ulozeny host key.

Na VM byly po zjisteni chybejicich nastroju nainstalovany balicky
`rpm`, `libxml2-utils` a `zypper`. SUSE RPM nebyly instalovany do Ubuntu.

### Patch a priprava

Patch pro `config.sh` byl doplnen o dalsi kontextovy radek, protoze puvodni
varianta selhala s GNU patch na predchozi ARM VM. Priprava na nove
x86_64 VM nyni prosla vcetne XML a Bash syntaxe.
Vystup: `/home/jartas/micro-os/prepared/SL-Micro-6.2`.

### Podpisy

Oba kandidati 13.1.0 i oba Tools RPM 13.0.0 z ISO maji platne RPM podpisy.
Pouzity klic byl ziskan z keyserveru a jeho plny fingerprint porovnan
s [oficialni strankou SUSE](https://www.suse.com/support/security/download-verification/):

```text
1C59 D66F CD52 563A 1693 3DBC FEC2 8EAF 09D9 EA69
```

Klic byl importovan pouze do izolovanych RPM databazi v projektu.
[Vysledky a verejny klic](./inspection/) jsou ulozeny i na Macu.
Platny podpis potvrzuje puvod a integritu, nikoli sam o sobe produktovou
podporu libovolne kombinace verzi.

### Skutecny obsah Packages ISO

ISO bylo stazeno z oficialniho portalu primo do VM a jeho SHA-256 souhlasi.
Nachazi se v `/home/jartas/micro-os/media/SL-Micro-Packages-6.2-x86_64-GM.iso`.
Read-only mount: `/home/jartas/micro-os/media/packages`.
Repozitarova metadata jsou v koreni media: `repodata/repomd.xml`.
ISO obsahuje 1178 RPM, mezi nimi:

| RPM | SHA-256 |
| --- | --- |
| `open-vm-tools-13.0.0-160000.2.2.x86_64.rpm` | `94b5f809ac3c2a4033027b8856057878b2c58f3daf42232e0a6efe1a3b063e88` |
| `libvmtools0-13.0.0-160000.2.2.x86_64.rpm` | `b7d986ecacdbbeabee9582d0436103b65dea9a382e4db36f42327f1aa5336f42` |

Pro GM build preferujeme tuto konzistentni sadu pred kandidaty 13.1.0.

### Zavislosti

Zypper byl spusten s izolovanym prazdnym rootem
`/home/jartas/micro-os/inspection/solver-root`, pouze s lokalnim ISO
repozitarem, zapnutou kontrolou GPG a volbou
`install --dry-run --no-recommends open-vm-tools`.

Vysledek: zavislosti uspesne vyreseny, 47 balicku, 15.8 MiB ke stazeni
z lokalniho media. Metadata repozitare byla validovana duveryhodnym SUSE
klicem. Dry-run neinstaloval system, nespoustel RPM scriptlety a neoveruje
funkcnost sluzeb nebo zavislosti celeho self-install profilu.
[Zaznam solveru](./inspection/iso-tools-solver.txt).

### Co jeste chybi

- Ubuntu 24.04 nabizi KIWI 9.25.22; to je starsi nez doporucena
  generace KIWI 10 pro Micro 6.2. Tato verze nebyla instalovana.
  Pripravit kompatibilni build prostredi podle dokumentace SUSE,
  napriklad s oficialnim KIWI 10 kontejnerem.
- Doplnit lokalni repo cestu do pracovni kopie definice.
- Overit KIWI schema a zavislosti celeho vybraneho image profilu.
- Overit misto pred buildem: virtualni disk ma 64 GB, root LVM jen
  priblizne 30 GB; po stazeni ISO zustava priblizne 20 GB volnych.
  LVM nebylo zvetseno. Dalsi kapacitu nejprve overit a zmenu odsouhlasit.
- Sestavit a otestovat vlastni ISO; finalni Tools test provest na ESXi.

## 10. Priprava KIWI 10 a aktualni blokace CPU

Zadavatel vybral profil **Base-SelfInstall**.

Na x86_64 Ubuntu byl po zjisteni chybejiciho Dockeru nainstalovan
`docker.io`. Sluzba Docker bezi. Oficialni SUSE build image byl uspesne
stazen:

```text
registry.suse.com/bci/kiwi:10.2
registry.suse.com/bci/kiwi@sha256:0fb77a36892633ba1042aa8af65c07b44b0ecbf2f13d06caf12eca4838178cb4
```

Image ma architekturu `amd64`. Probe byl spusten bez site, bez privileged
rezimu a bez pripojeni projektu. Spusteni `/bin/bash` a `kiwi-ng --version`
selhalo s navratovym kodem 132 (SIGILL / Illegal instruction).
KIWI verze ani schema tedy zatim nebyly overeny. Po probe nezustal bezici
ani zastaveny kontejner.

### Zjistena pricina / predpoklad k dalsimu overeni

`lscpu` hlasi `QEMU Virtual CPU version 2.5+` a pouze 1 CPU.
Ve flags chybi `popcnt`, `ssse3`, `sse4_1` a `sse4_2`.
Dokumentace Micro 6.2 pozaduje AMD64/Intel 64 **v2**, konkretne:

```text
cx16 lahf_lm popcnt ssse3 sse4_1 sse4_2
```

Soucasny emulovany CPU tyto pozadavky nesplnuje.
Je to konkretni blokace pro spousteni ciloveho Micro a pravdepodobna
pricina selhani build image. Funkcnost kontejneru je nutne znovu overit
po zmene modelu CPU; samotne oznaceni `x86_64` nestaci.

- [Pozadavky Micro 6.2 na CPU](https://documentation.suse.com/sle-micro/6.2/html/Micro-deployment-images/index.html#hardware-requirements-cpu-identification).
- [UTM: nastaveni modelu CPU](https://docs.getutm.app/settings-qemu/system/#cpu).

### Nutny dalsi krok

1. Korektne vypnout Ubuntu.
2. V UTM upravit nastaveni VM, sekci System / CPU.
3. Vybrat model `max`, pokud je nabizen, pripadne novy model podporujici
   vsechny vyse uvedene instrukce, napr. `Haswell`.
4. Ponechat emulaci x86_64 a 8 GB RAM.
   Multicore na ARM emulujicim x86 ma dle UTM dalsi omezeni; neni nutne
   jej v tomto kroku vynucovat.
5. Spustit VM a znovu overit IP, CPU flags a SUSE kontejner.

Ubuntu neni nutne reinstalovat. ISO a pripravene podklady zustavaji na disku.
Disk ani LVM nebyly zmeneny; po stazeni kontejneru zbyva asi 18 GB na root.
Vlastni KIWI build nebyl spusten a offline repo cesta v definici zatim
zustava nezmenena.

## 11. Overeni po zmene CPU na Haswell

Po zmene UTM CPU hlasi VM `Intel Core Processor (Haswell)` a vsechny
pozadovane v2 flags jsou pritomne. SUSE kontejner uz funguje:
`kiwi-ng --version` vypisuje **10.2.33**.
Packages ISO bylo po rebootu znovu pripojeno read-only na stejnou cestu.

KIWI uspesne nacetl upravenou definici a pro `Base-SelfInstall` vybral:

```text
Base-SelfInstall,container-host,x86-self_install,bootloader,self_install
```

`image info --print-kiwi-env` uspesne overilo nacteni a validaci definice
a potvrdilo OEM typ, UEFI a nastaveni Btrfs snapshotu. Probe bezel bez
site a s read-only definici. CPU blokace je odstranena.

Volitelna kontrola `image info --resolve-package-list` proti lokalnimu
ISO narazila na chybejici Python modul `solv` uvnitr oficialniho kontejneru.
BCI repozitar nenabidl `python3-solv`. Toto neni chyba vyreseni zavislosti
image; solver se v tomto prikazu vubec nespustil.
Predchozi samostatny Zypper dry-run pro Tools zustava platny.
Pro cely image bude nutne pouzit standardni KIWI prepare/build se Zypperem,
nebo nejprve dodat kompatibilni SAT solver plugin pro image info.

Vlastni build stale nebyl spusten. Na root disku zustava asi 18 GB;
pred dlouhym buildem overit volne extenty v LVM a odsouhlasit pripadne
rozsireni root. Nepouzivat starsi Ubuntu KIWI jako nahradu overeneho 10.2.33.

### 11.1 Zahajeni prvniho offline buildu

Po souhlasu zadavatele byl root LV zvetsen pomoci
`lvextend -r -l +100%FREE /dev/ubuntu-vg/ubuntu-lv`.
Filesystem ma nyní priblizne 60 GB, po rozsireni zbyvalo 47 GB volnych.
Zadne oddily ani uzivatelske soubory nebyly odstraneny.

Prvni pokus v `build/base-selfinstall-01` pouzil chybne URI `/repo`.
KIWI jej prelozilo na `/` a instalace systemu nenasla poskytovatele balicku.
Nejde o dukaz chybejicich RPM na ISO.

Druhy pokus v `build/base-selfinstall-02` pouziva spravne `dir:///repo`,
ktere KIWI prelozilo na `/repo`. Bootstrap prosel a probiha instalace
systemovych balicku vcetne `open-vm-tools`. Dokonceni zatim neni potvrzeno.

Build je spusten v Dockeru s `--network none`, `--privileged`, `/dev:/dev`,
read-only mountem definice na `/image`, read-only ISO repozitarem na `/repo`
a zapisovatelnym vystupem na `/build`. Privileged rezim je omezen na
dedikovanou testovaci VM; nesmi se takto spoustet na produkcnim hostiteli.

Prikaz uvnitr kontejneru:

```bash
kiwi-ng --profile Base-SelfInstall system build \
  --description /image --target-dir /build \
  --ignore-repos --add-repo dir:///repo,rpm-md,micro-packages
```

Prubezny log na VM:
`/home/jartas/micro-os/build/base-selfinstall-02/build.log`.
Sestaveni zatim nelze oznacit za hotove ISO ani za overenou instalaci.
