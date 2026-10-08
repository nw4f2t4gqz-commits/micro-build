# SUSE Linux Micro 6.2: sestaveni offline ISO s VMware Tools

## 1. Cil a rozsah

Tento navod pripravuje na samostatne Linuxove x86_64 VM vlastni
**Base-SelfInstall ISO SUSE Linux Micro 6.2** s `open-vm-tools`.
Balicek je soucasti instalovaneho systemu a jeho sluzba se zapina pri buildu.
Cilova instalace nema vyzadovat internet ani dalsi balickove medium.
Zachovavame UEFI, Btrfs, read-only root a transakcni aktualizace.

Prikazy spoustejte v Bash na build VM. Nepouzivejte produkcni hostitel:
KIWI potrebuje privilegovany kontejner, mounty a pristup k `/dev`.
Ubuntu/Debian, SUSE i dalsi Linuxove distribuce mohou slouzit jako hostitel,
pokud splnuji pozadavky nize. Instalace hostitelskych nastroju se lisi
podle distribuce; samotny KIWI bezi v jednotnem SUSE kontejneru.
Overena hostitelska distribuce je Ubuntu 24.04 x86_64.

**Stav overeni k 2026-10-08:** integrita Packages ISO, podpisy Tools RPM,
dry-run zavislosti Tools, aplikace patche a validace definice jsou overeny.
Kompletni build byl zahajen; jeho uspesne dokonceni a instalace na ESXi
zatim nejsou potvrzeny. Navod neni prohlasenim o hotovem otestovanem ISO.

Posledni kontrola 2026-10-08 22:44 CEST: instalace balicku a `config.sh`
prosly, initrd a GRUB byly vytvoreny. Build aktivne synchronizuje root
filesystem do Btrfs RAW image; hotove instalacni ISO jeste neni k dispozici.

## 2. Pozadavky na build VM

- Linux **x86_64**, pristup k `sudo`, Bash a Docker Engine.
- CPU alespon x86-64-v2. Pozadovane flags Micro:
  `cx16 lahf_lm popcnt ssse3 sse4_1 sse4_2`.
- Doporuceno 4 CPU a 8 GB RAM.
- Doporuceno alespon 80 GB disk a 40 GB volneho prostoru pro prvni build.
  Opakovane buildy potrebuji dalsi misto.
- Pracovni adresar na lokalnim Linuxovem filesystemu, napr. ext4 nebo XFS;
  nepouzivat sitovy share pro image-root a mount operace.
- Hostitel musi umoznovat loop zarizeni, mounty a privilegovane kontejnery.
  Omezeny neprivilegovany kontejner misto plne build VM nemusi stacit.
- Internet pro uvodni instalaci nastroju a stazeni kontejneru a ISO.
  Samotny build nize ma sit vypnutou.
- Opravneni k pouziti SUSE produktu a medii. Uprava image nenahrazuje
  subscription a je nutne respektovat podminky podpory a redistribuce.

Overeni:

```bash
uname -m
grep -m1 '^flags' /proc/cpuinfo
df -h .
free -h
```

`uname -m` musi vratit `x86_64`. Pokud chybi CPU flags nebo kontejner
konci `Illegal instruction` (kod 132), nejprve upravte dostupny CPU model
na hypervizoru. Samotne oznaceni architektury nestaci.

Pripadne zvetseni filesystemu je samostatna administracni operace.
Neprovadejte naslepo `lvextend`: nejprve zkontrolujte `lsblk`, `vgs`,
`lvs`, filesystem a zalohy. Navod automaticky nemeni rozdeleni disku.

## 3. Co je v repozitari a co stahnout zvlast

| Vstup / vystup | Umisteni | Soucast repozitare |
| --- | --- | --- |
| Oficialni definice a skripty SUSE vcetne licence | [upstream/SL-Micro-6.2/](./upstream/SL-Micro-6.2/) | Ano |
| Metadata revize a checksumy zdroju | [upstream/](./upstream/) | Ano |
| Uprava self-install profilu | [patches/selfinstall-vmware-tools.patch](./patches/selfinstall-vmware-tools.patch) | Ano |
| Pripravny skript | [scripts/prepare-image.sh](./scripts/prepare-image.sh) | Ano |
| Verejny SUSE podpisovy klic a zaznamy kontrol | [inspection/](./inspection/) | Ano |
| Referencni spec a metadata kandidatu Tools | [tools-source/](./tools-source/) | Ano, pro tento build nejsou potreba |
| Packages ISO, asi 2.24 GB | `media/SL-Micro-Packages-6.2-x86_64-GM.iso` | Ne, stahnout |
| SUSE KIWI kontejner | Docker image store | Ne, stahnout |
| Upraveny popis image | `prepared/SL-Micro-6.2/` | Ne, generuje skript |
| Build root, logy, RAW a vysledne ISO | `build/<nazev-pokusu>/` | Ne, generuje KIWI |
| Samostatne kandidati Tools 13.1.0 | `packages/candidates/*.rpm` | Ne a nejsou potreba |

Oficialni zdroj je pripnuty na OBS revizi 24 s identifikatorem
`f20fd430845c88fcda62d025b7ac6631` v projektu
`SUSE:SLFO:Products:SL-Micro:6.2`, balicek `SL-Micro`.
Nevymenujte definici za novejsi bez kontroly kompatibility s GM mediem.

Packages ISO obsahuje **1178 RPM**, vcetne:

- `open-vm-tools-13.0.0-160000.2.2.x86_64.rpm`
- `libvmtools0-13.0.0-160000.2.2.x86_64.rpm`

Samostatna instalace Tools 13.1.0 z dalsiho repozitare neni potreba.
GM medium je pevny snapshot a neobsahuje automaticky pozdejsi aktualizace.
Puvodni bootovatelne self-install ISO neni vstupem tohoto buildu.

## 4. Ziskani projektu

Pokud je postup uz commitnuty v repozitari:

```bash
git clone https://github.com/jartas/DevOps.git
cd DevOps/micro-os
export PROJECT="$PWD"
```

Pokud jeste nebyl commitnuty, samotny clone nove soubory neziska.
Preneste aktualni slozku `micro-os` vcetne `upstream`, `patches`,
`scripts` a `inspection` do build VM, potom do ni prejdete a nastavte
`export PROJECT="$PWD"`. Velka ISO ani stare build rooty prenest nemusite.
Tento navod sam neprovadi commit nebo push.

Vsechny dalsi prikazy pocitaji s timto pracovnim adresarem. V novem shellu
znovu provedte `cd` do projektu a `export PROJECT="$PWD"`.

## 5. Hostitelske nastroje

Potreba: `git`, `curl`, `jq`, `gnupg`, `rpm`, `patch`, `xmllint`,
`shasum`, `sha256sum`, `mount`, Docker Engine a jeho bezici daemon.

Ubuntu / Debian:

```bash
sudo apt-get update
sudo apt-get install -y \
  git curl jq gnupg rpm patch libxml2-utils libdigest-sha-perl docker.io
sudo systemctl enable --now docker
```

Na SUSE odpovidaji zakladni nastroje balickum:

```bash
sudo zypper install git curl jq gpg2 rpm patch libxml2-tools perl-Digest-SHA
```

Na Fedora / RHEL-kompatibilnim hostiteli:

```bash
sudo dnf install git curl jq gnupg2 rpm patch libxml2 perl-Digest-SHA
```

Pro posledni dve varianty pripravte podporovany Docker Engine podle
[oficialniho navodu pro hostitelskou distribuci](https://docs.docker.com/engine/install/),
pak `sudo systemctl enable --now docker`. Nazvy a dostupnost balicku
se mezi verzemi distribuci lisi. KIWI do hostitelskeho OS neinstalujte.

```bash
sudo docker version
command -v shasum
command -v xmllint
```

Nepovolujte kvuli buildu neautentizovany Docker TCP socket. Nize pouzivame
`sudo`, neni nutne pridavat uzivatele do skupiny `docker`.

## 6. Stazeni a overeni Packages ISO

Z [oficialniho SUSE portalu](https://www.suse.com/download/sle-micro/)
vyberte Micro 6.2 / x86_64 a binarni Packages ISO:

```text
SL-Micro-Packages-6.2-x86_64-GM.iso
```

Nejde o bootovatelne medium. Nestahujte `-Source.iso`.
Ulozte soubor do `$PROJECT/media/`. Portal muze vyzadovat prihlaseni;
do projektu neukladejte hesla, tokeny ani docasne podepsane URL.

Alternativni download pres aktualni metadata verejneho portalu:

```bash
(
  set -euo pipefail
  cd "$PROJECT"
  mkdir -p media
  iso=media/SL-Micro-Packages-6.2-x86_64-GM.iso
  test ! -e "$iso"
  test ! -e "$iso.part"
  url=$(curl -fsSL https://www.suse.com/download/ajax/2913/ |
    jq -er '.downloads[] |
      select(.filename=="SL-Micro-Packages-6.2-x86_64-GM.iso") | .url')
  curl --fail --location --show-error "$url" -o "$iso.part"
  printf '%s  %s\n' \
    0d9abdf54056c06c3c01299c7997f03bcab19482ed03d6ea8960b8dce8f83bed \
    "$iso.part" | sha256sum -c -
  mv "$iso.part" "$iso"
)
```

Pred pouzitim overte, ze soucet odpovida i aktualnimu SUSE portalu.
Pokud prikaz selze, nepreskakujte checksum; prohlednete chybu nebo
stahnete medium pres portal. Nedokonceny `.part` soubor neni hotove ISO.

Pripojeni pouze pro cteni:

```bash
mkdir -p "$PROJECT/media/packages"
sudo mount -o loop,ro \
  "$PROJECT/media/SL-Micro-Packages-6.2-x86_64-GM.iso" \
  "$PROJECT/media/packages"
findmnt "$PROJECT/media/packages"
test -f "$PROJECT/media/packages/repodata/repomd.xml"
find "$PROJECT/media/packages" -name 'open-vm-tools*.rpm'
```

Po restartu build VM mount obnovte. Behem buildu jej neodpojujte.

## 7. Overeni Tools RPM

Pouzijeme oddelenou RPM databazi, nikoli databazi hostitelskeho systemu.
Plny fingerprint klice pro Micro 6.x overte proti
[oficialni strance SUSE](https://www.suse.com/support/security/download-verification/).
Ocekavany fingerprint:

```text
1C59 D66F CD52 563A 1693 3DBC FEC2 8EAF 09D9 EA69
```

```bash
(
  set -euo pipefail
  cd "$PROJECT"
  mkdir -p verification/gnupg verification/rpmdb
  chmod 700 verification/gnupg
  key=inspection/suse-micro-signing-key.asc
  fingerprint=$(gpg --homedir "$PWD/verification/gnupg" \
    --show-keys --with-colons "$key" |
    awk -F: '$1=="fpr" {print $10; exit}')
  test "$fingerprint" = 1C59D66FCD52563A16933DBCFEC28EAF09D9EA69
  rpm --dbpath "$PWD/verification/rpmdb" --initdb
  rpm --dbpath "$PWD/verification/rpmdb" --import "$key"
  for file in \
    media/packages/x86_64/open-vm-tools-13.0.0-160000.2.2.x86_64.rpm \
    media/packages/x86_64/libvmtools0-13.0.0-160000.2.2.x86_64.rpm
  do
    rpm --dbpath "$PWD/verification/rpmdb" -Kv "$file"
  done
)
```

Podpisy musi byt `OK`, nikoli `NOKEY` nebo `BAD`.
RPM neinstalujte primo do hostitelskeho Ubuntu/Fedora.
Predchozi izolovany Zypper dry-run proti pouze tomuto ISO uspesne vyresil
Tools a 47 balicku zavislosti. To neni dukaz uspesneho celeho buildu.

## 8. Priprava upravene definice

```bash
cd "$PROJECT"
bash scripts/prepare-image.sh
```

Skript overi checksumy menenych upstream souboru, kopiruje definici,
aplikuje patch bez fuzzy prizpusobeni a overi XML a Bash syntaxi.
Existujici vystup neprepise. Pro novy pokus muzete zadat jinou cestu:

```bash
bash scripts/prepare-image.sh prepared/SL-Micro-6.2-next
```

Nize pouzivame vychozi `prepared/SL-Micro-6.2`.
Patch rozsiruje Tools blok na `x86-vmware,x86-self_install` a pro standardni
x86 self-install zapina `vmtoolsd.service`. Nemeni RT ani ARM profily.
Sluzba vyzaduje `vgauthd`; automaticke enable overte na vyslednem rootu.
Spusteni sluzeb mimo VMware neni validni runtime test.

Definice ponechava upstream `obsrepositories:/`.
Build tento zdroj **explicitne nahrazuje** parametry
`--ignore-repos --add-repo dir:///repo,rpm-md,micro-packages`.
Neni potreba rucne prepisovat upstream XML.

## 9. KIWI build kontejner

Pouzijeme konkretni overeny digest oficialniho SUSE KIWI image:

```bash
export KIWI_IMAGE='registry.suse.com/bci/kiwi@sha256:0fb77a36892633ba1042aa8af65c07b44b0ecbf2f13d06caf12eca4838178cb4'
sudo docker pull "$KIWI_IMAGE"
sudo docker run --rm --network none --entrypoint /bin/bash \
  "$KIWI_IMAGE" -c 'kiwi-ng --version'
```

Overena verze je **10.2.33**. Digest pochazi z tagu `bci/kiwi:10.2`.
Pin omezuje nechtenou zmenu build prostredi; pokud image prestane byt
dostupny, novy digest nejprve otestujte a aktualizujte dokumentaci.

Validace vybraneho profilu:

```bash
sudo docker run --rm --network none \
  -v "$PROJECT/prepared/SL-Micro-6.2:/image:ro" \
  --entrypoint /bin/bash "$KIWI_IMAGE" -c \
  'kiwi-ng --profile Base-SelfInstall image info \
    --description /image --print-kiwi-env'
```

Ocekavane profily:
`Base-SelfInstall,container-host,x86-self_install,bootloader,self_install`.
`image info --resolve-package-list` v tomto kontejneru selhava kvuli
chybejicimu modulu `solv`. Neni potreba pro standardni build se Zypperem;
neinstalujte kvuli tomu starsi KIWI z hostitelske distribuce.

## 10. Spusteni offline buildu

Spoustejte jen jeden build soucasne. Nejprve overte mount ISO a misto.
Vyberte **novy** adresar pro kazdy pokus, neprepouzivejte nedokonceny root.
KIWI pracuje se zarizenimi; nepripojujte build VM produkcni datove disky.

```bash
(
  set -euo pipefail
  cd "$PROJECT"
  export BUILD_DIR="$PROJECT/build/base-selfinstall-01"
  test -f "$PROJECT/media/packages/repodata/repomd.xml"
  test ! -e "$BUILD_DIR"
  mkdir -p "$BUILD_DIR"
  sudo docker run --rm --name micro-kiwi-build \
    --network none --privileged \
    -v /dev:/dev \
    -v "$PROJECT/prepared/SL-Micro-6.2:/image:ro" \
    -v "$PROJECT/media/packages:/repo:ro" \
    -v "$BUILD_DIR:/build" \
    --entrypoint /bin/bash "$KIWI_IMAGE" -c \
    'set -o pipefail
     kiwi-ng --profile Base-SelfInstall system build \
       --description /image --target-dir /build \
       --ignore-repos --add-repo dir:///repo,rpm-md,micro-packages \
       2>&1 | tee /build/build.log'
)
```

Prikaz bezi v popredi; neukoncujte terminal/SSH ani VM.
Vlastni build nema sit, pouziva pouze ISO. Uvodni pull image a download
ISO jsou online kroky. Privileged rezim neni izolacni bezpecnostni hranice:
kontejner muze ovlivnit hostitelskou build VM.

**Dulezite:** URI musi byt `dir:///repo`, ne `/repo`. Nespravna cesta
muze projit bootstrapem, ale nasledne instalace systemu nenajde balicky.
Neobchazejte chyby vypnutim kontrol podpisu nebo odstranenim potrebnych
balicku. Pokud instalace skutecne nema poskytovatele, ulozte log a zjistete,
zda je pricina v repo ceste, verzi definice nebo dostupnosti RPM.

V dalsim terminalu ze stejneho projektu:

```bash
sudo docker ps
tail -f build/base-selfinstall-01/build.log
df -h .
```

Procenta instalace balicku nejsou procenta celeho buildu. Nasleduji
konfigurace, initrd, filesystem, RAW a instalacni ISO.
Pri chybe zachovejte adresar a log. Dalsi pokus dejte napr. do
`build/base-selfinstall-02`; nejprve zkontrolujte, ze predchozi build skoncil.

## 11. Kontrola vystupu

Po uspesnem navratovem kodu 0:

```bash
find build/base-selfinstall-01 -maxdepth 2 -type f \
  \( -name '*.iso' -o -name '*.raw' -o -name '*.packages' \
     -o -name '*.verified' -o -name '*.sha256' \) -ls
```

Vystup muze byt v podadresari podle KIWI konfigurace.
Vyhledejte skutecne `*.install.iso`; nevydavejte vstupni Packages ISO
za vysledek. Ulozte SHA-256 hotoveho ISO, jeho seznam balicku, build log,
revizi definice, patch a digest kontejneru.

```bash
find build/base-selfinstall-01 -type f -name '*.packages' \
  -exec grep -H -E '^(open-vm-tools|libvmtools0)\|' {} \;
find build/base-selfinstall-01 -type f -name '*.install.iso' \
  -exec sha256sum {} \;
```

Ocekavame Tools 13.0.0 z GM ISO. Pokud neni ISO vytvoreno nebo seznam
balicku neobsahuje Tools, build nesplnil zadani.

Dalsi kontrola pripraveneho rootu v kontejneru
(cesta odpovida pozorovanemu KIWI layoutu, overte ji ve svem vystupu):

```bash
sudo docker run --rm --network none \
  -v "$PROJECT/build/base-selfinstall-01/build/image-root:/target:ro" \
  --entrypoint /bin/bash "$KIWI_IMAGE" -c \
  'set -e
   rpm --root /target -q open-vm-tools libvmtools0
   systemctl --root=/target is-enabled vmtoolsd.service
   systemctl --root=/target is-enabled vgauthd.service'
```

Kontrola rootu je doplnkova. Obsah a bootovatelnost finalniho ISO musi
potvrdit instalacni test, nikoli jen pritomnost balicku v docasnem rootu.
Overte take, ze image neobsahuje hesla, privatni SSH klice, subscription
tokeny ani identitu build stroje.

## 12. Offline instalacni test na VMware

1. Vytvorte novou testovaci x86_64 VM s UEFI a prazdnym diskem.
   Pro zacatek pouzijte alespon 2 CPU, 4 GB RAM a 32 GB disk.
2. Odpojte sitovou kartu a pripojte pouze vysledne self-install ISO.
3. Nainstalujte system. **Self-install muze prepsat cilovy disk**;
   nepripojujte zadne produkcni disky.
4. Odpojte ISO a spustte system z disku.
5. Dokoncete potrebnou lokalni first-boot konfiguraci.
6. Overte:

   ```bash
   rpm -q open-vm-tools libvmtools0
   vmtoolsd --version
   systemctl is-enabled vmtoolsd.service
   systemctl is-active vmtoolsd.service
   systemctl is-active vgauthd.service
   journalctl -u vmtoolsd.service -b --no-pager
   ```

7. Ve vSphere overte bezici Tools; guest-managed oznaceni je ocekavane.
8. Otestujte guest shutdown a restart z vSphere i dalsi boot.
9. Pripojte sit a overte komunikaci a reportovani IP.
10. Overte read-only root a transakcni mechanismus Micro.
11. Guest customization, Secure Boot a quiesced zalohy testujte samostatne,
    pokud je budete pouzivat. Samotny bezici vmtoolsd jejich funkci nedokazuje.

Akceptace: nova VM bez internetu a bez druheho Packages media ma po
instalaci funkcni Tools, ktere preziji restart a umozni shutdown/restart
z vSphere. Az potom lze image oznacit jako funkcni pro zadani.

## 13. Plne air-gap build a uklid

Pokud nema mit internet ani pripravna build VM, predem preneste:

- projektove soubory,
- overene Packages ISO,
- Docker Engine a hostitelske zavislosti pro danou distribuci,
- export konkretniho KIWI kontejneru.

Na pripojenem Linuxovem stroji s nastavenym `KIWI_IMAGE`:

```bash
sudo docker pull "$KIWI_IMAGE"
sudo docker save -o kiwi-10.2.tar "$KIWI_IMAGE"
sha256sum kiwi-10.2.tar
```

Preneste archiv i soucet, porovnejte checksum na cilove VM a nactete:

```bash
sudo docker load -i kiwi-10.2.tar
sudo docker image inspect "$KIWI_IMAGE"
```

Pak pokracujte bez `docker pull` kroky 6-12 s lokalnimi vstupy.
Nemichejte aktualizovane RPM s GM zakladem bez noveho reseni zavislosti.

Po ukonceni vsech buildu lze ISO odpojit:

```bash
sudo umount "$PROJECT/media/packages"
```

Vystupy a logy mazte jen cilene po kontrole, nikoli pres mazani korene
projektu nebo wildcard nad neznamymi adresari. RPM kandidati 13.1.0
a historicke inspection logy nejsou nutnym vstupem noveho GM buildu.

## 14. Zdroje

- [SUSE Micro 6.2: customizace a KIWI](https://documentation.suse.com/sle-micro/6.2/html/Micro-developers-guide/index.html)
- [Pozadavky CPU a image](https://documentation.suse.com/sle-micro/6.2/html/Micro-deployment-images/index.html)
- [Self-install nasazeni](https://documentation.suse.com/sle-micro/6.2/html/Micro-deployment-selfinstall-images/index.html)
- [VMware nasazeni a open-vm-tools](https://documentation.suse.com/sle-micro/6.2/html/Micro-deployment-vmdk/index.html)
- [Oficialni OBS projekt](https://build.opensuse.org/project/show/SUSE:SLFO:Products:SL-Micro:6.2)
- [SUSE download portal](https://www.suse.com/download/sle-micro/)
- [Overeni podpisu a klicu SUSE](https://www.suse.com/support/security/download-verification/)
- [Transakcni aktualizace](https://documentation.suse.com/sle-micro/6.2/html/Micro-transactional-updates/index.html)
- [KIWI typy image a installiso](https://osinside.github.io/kiwi/image_types_and_results.html)
