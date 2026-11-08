#!/bin/bash


case "$1" in
    "-s"|"search")
        PKG_QUERY=$2
        if [ -z "$PKG_QUERY" ]; then
            echo "[-] Hata: Aranacak paket adını girmedin."
            echo "Kullanım: vph ara <paket_adi>"
            exit 1
        fi
        
        echo "[*] Searching on Github: '$PKG_QUERY'..."
        
        # GitHub Contents API kullanarak void-packages reposundaki srcpkgs klasörünü sorgula
        # (Not: GitHub API rate-limit'e takılmamak için basit bir curl + grep kombinasyonu kullanıyoruz)
	echo "Results:"
        API_URL="https://api.github.com/repos/void-linux/void-packages/contents/srcpkgs"
        
        # API'den gelen JSON yanıtı çekip paket adlarını filtreleyelim
        curl -s "$API_URL" | grep '"name":' | cut -d '"' -f 4 | grep -i "$PKG_QUERY"
        
        if [ $? -ne 0 ]; then
            echo "[-] Nothing Maches."
        fi
        ;;
    "setup"|"-u")
        echo "[*] VPH ortamı ve bağımlılıkları kuruluyor..."
        # Eksik temel araçları tespit edip kuralım
        MISSING_PKGS=""
        
        if ! command -v curl &> /dev/null; then
            MISSING_PKGS="${MISSING_PKGS} curl"
        fi
        
        if ! command -v wget &> /dev/null; then
            MISSING_PKGS="${MISSING_PKGS} wget"
        fi
        
        if ! command -v svn &> /dev/null; then
            MISSING_PKGS="${MISSING_PKGS} subversion"
        fi
        
        if ! command -v git &> /dev/null; then
            MISSING_PKGS="${MISSING_PKGS} git"
        fi

        if [ -n "${MISSING_PKGS}" ]; then
            echo "[*] Eksik bağımlılıklar kuruluyor:${MISSING_PKGS}"
            sudo xbps-install -Sy ${MISSING_PKGS}
        else
            echo "[✔] Tüm temel bağımlılıklar (curl, wget, svn, git) zaten kurulu.xbps-src için vph install minimal"
        fi
        ;;
        
    "install"|"-k")
        PKG_NAME=$2
        echo "[+] '$PKG_NAME' is installing"
        svn export "https://github.com/void-linux/void-packages/trunk/srcpkgs/${PKG_NAME}" "srcpkgs/${PKG_NAME}" --force
	REPO_DIR="$HOME/void-packages"
	echo "[+] installation complette"
	if [ $PKG_NAME = "minimal" ]; then
            echo "[*] void-packages altyapısı hazırlanıyor..."
            mkdir -p "${REPO_DIR}"
            wget -qO- "https://github.com/void-linux/void-packages/archive/refs/heads/master.tar.gz" | tar xz -C "$HOME" --wildcards "*/common" "*/xbps-src" "*/etc"
            mv "$HOME/void-packages-master" "${REPO_DIR}" 2>/dev/null || true
            cd "${REPO_DIR}/void-packages-master" || exit 1
            ./xbps-src binary-bootstrap
        else
            cd "${REPO_DIR}" || exit 1
        fi
        ;;
        
    *)
        echo "Kullanım: vph {search|-s} <paket_adi>"
        echo "          vph {install|-k} <paket_adi>"
        exit 1
        ;;
esac


# Bu versiyon sonraki versiyona keep my legacy diyor ama ne kadar keep bilinmiyor.
