#!/bin/bash

COMMAND="$1"
PKG_NAME="$2"
REPO_DIR="$HOME/void-packages"

case "${COMMAND}" in
    "-s"|"search")
        if [ -z "${PKG_NAME}" ]; then
            echo "[-] Hata: Aranacak paket adını girmedin."
            echo "Kullanım: vph ara <paket_adi>"
            exit 1
        fi

        echo "[*] Searching on Github: '${PKG_NAME}'..."
        API_URL="https://api.github.com/repos/void-linux/void-packages/contents/srcpkgs"
        
        RESULTS=$(curl -s "${API_URL}" | grep '"name":' | cut -d '"' -f 4 | grep -i "${PKG_NAME}")
        
        if [ -z "${RESULTS}" ]; then
            echo "[-] Nothing Matches."
        else
            echo "Results:"
            echo "${RESULTS}"
        fi
        ;;

    "setup"|"-u")
        echo "[*] VPH ortamı ve temel bağımlılıklar kontrol ediliyor..."

        MISSING_PKGS=""
        if ! command -v curl &> /dev/null; then MISSING_PKGS="${MISSING_PKGS} curl"; fi
        if ! command -v wget &> /dev/null; then MISSING_PKGS="${MISSING_PKGS} wget"; fi
        if ! command -v svn &> /dev/null; then MISSING_PKGS="${MISSING_PKGS} subversion"; fi
        if ! command -v git &> /dev/null; then MISSING_PKGS="${MISSING_PKGS} git"; fi

        if [ -n "${MISSING_PKGS}" ]; then
            echo "[*] Eksik bağımlılıklar kuruluyor:${MISSING_PKGS}"
            sudo xbps-install -Sy ${MISSING_PKGS}
        else
            echo "[✔] Tüm temel bağımlılıklar zaten kurulu."
        fi

        if [ ! -d "${REPO_DIR}/common" ]; then
            echo "[*] void-packages altyapısı indiriliyor ve ayıklanıyor..."
            mkdir -p "${REPO_DIR}"
            wget -qO- "https://github.com/void-linux/void-packages/archive/refs/heads/master.tar.gz" | tar xz -C "$HOME" --wildcards "*/common" "*/xbps-src" "*/etc"
            mv "$HOME/void-packages-master" "${REPO_DIR}" 2>/dev/null || true
            
            echo "[*] binary-bootstrap çalıştırılıyor (bu biraz sürebilir)..."
            cd "${REPO_DIR}" || exit 1
            ./xbps-src binary-bootstrap
        else
            echo "[✔] void-packages altyapısı zaten mevcut."
        fi

        echo "[✔] Setup tamamlandı!"
        ;;

    "install"|"-k")
        if [ -z "${PKG_NAME}" ]; then
            echo "[-] Hata: Kurulacak paket adını girmedin."
            echo "Kullanım: vph install <paket_adi>"
            exit 1
        fi

        # OTOMATİK SETUP KONTROLÜ: Altyapı yoksa sessizce kur!
        if [ ! -d "${REPO_DIR}/common" ]; then
            echo "[!] Altyapı eksik, otomatik setup tetikleniyor..."
            bash "$0" setup
        fi

        cd "${REPO_DIR}" || { echo "[-] Hata: ${REPO_DIR} dizinine girilemedi!"; exit 1; }

        mkdir -p "srcpkgs"
        echo "[+] '${PKG_NAME}' paketi çekiliyor..."
        
        # Önce SVN export dene
        if command -v svn &> /dev/null; then
            svn export "https://github.com/void-linux/void-packages/trunk/srcpkgs/${PKG_NAME}" "srcpkgs/${PKG_NAME}" --force &> /dev/null
        fi

        # Eğer SVN başarısız olduysa veya klasör oluşmadıysa WGET + TAR B planını devreye sok!
        if [ ! -d "srcpkgs/${PKG_NAME}" ]; then
            echo "[*] SVN başarısız oldu, Wget yedeği deneniyor..."
            rm -rf "srcpkgs/${PKG_NAME}" "void-packages-master"
            wget -qO- "https://github.com/void-linux/void-packages/archive/refs/heads/master.tar.gz" | tar xz --wildcards "*/srcpkgs/${PKG_NAME}/*"
            if [ -d "void-packages-master/srcpkgs/${PKG_NAME}" ]; then
                mv "void-packages-master/srcpkgs/${PKG_NAME}" "srcpkgs/"
                rm -rf "void-packages-master"
            fi
        fi

        # Son kontrol
        if [ ! -d "srcpkgs/${PKG_NAME}" ]; then
            echo "[-] Hata: '${PKG_NAME}' paketi hiçbir şekilde bulunamadı veya indirilemedi."
            exit 1
        fi

        echo "[+] Paket tarifi hazır. Derleme başlatılıyor..."
        
        # Derle ve kur
        ./xbps-src pkg "${PKG_NAME}" && sudo xbps-install -R hostdir/binpkgs "${PKG_NAME}"

        if [ $? -eq 0 ]; then
            echo "[✔] Installation complete! '${PKG_NAME}' sisteme kuruldu."
        else
            echo "[-] Derleme veya kurulum sırasında hata oluştu."
        fi
        ;;

    *)
        echo "Kullanım: vph {search|-s} <paket_adi>"
        echo "          vph {install|-k} <paket_adi>"
        echo "          vph {setup|-u}"
        exit 1
        ;;
esac
