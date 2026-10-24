
#!/usr/bin/env bash
set -Eeuo pipefail

KEY_URL="https://ngosen.github.io/ngosen/apt/ngosen.gpg"
KEY_FILE="/usr/share/keyrings/ngosen.gpg"
REPO_FILE="/etc/apt/sources.list.d/ngosen.list"

get_codename() {
    . /etc/os-release
    printf '%s' "${UBUNTU_CODENAME:-$VERSION_CODENAME}"
}

install_ngosen() {
    local codename
    codename="$(get_codename)"

    echo "Sẽ cài Ngó Sen cho Ubuntu nền: $codename"
    read -r -p "Tiếp tục? [y/N]: " answer
    [[ "$answer" =~ ^[Yy]$ ]] || return 0

    # Tải khóa về thư mục tạm, sau đó mới cài vào hệ thống.
    local tmp
    tmp="$(mktemp)"
    trap 'rm -f "$tmp"' RETURN

    curl -fL --retry 2 "$KEY_URL" -o "$tmp"
    sudo install -D -m 0644 "$tmp" "$KEY_FILE"

    printf 'deb [signed-by=%s] https://ngosen.github.io/ngosen/apt %s main\n' \
        "$KEY_FILE" "$codename" |
        sudo tee "$REPO_FILE" >/dev/null

    sudo apt update
    sudo apt install fcitx5-ngosen

    echo
    echo "Đã hoàn tất bước cài đặt."
    echo "Hãy khởi động lại Fcitx5:"
    echo "fcitx5 -rd"
    echo "Nếu vẫn chưa gõ được, hãy đăng xuất rồi đăng nhập lại."
}

uninstall_ngosen() {
    echo "Chỉ gỡ gói Ngó Sen, không tự gỡ Fcitx5."
    read -r -p "Bạn có chắc chắn? [y/N]: " answer
    [[ "$answer" =~ ^[Yy]$ ]] || return 0

    sudo apt remove fcitx5-ngosen
    fcitx5 -rd || true

    echo "Đã thực hiện gỡ gói Ngó Sen."
    echo "Kho APT và khóa GPG vẫn được giữ lại để tiện cài lại."
}

while true; do
    echo
    echo "===== NGÓ SEN LINUX TOOLS ====="
    echo "1. Cài đặt / cập nhật Ngó Sen"
    echo "2. Gỡ bỏ Ngó Sen"
    echo "0. Thoát"
    read -r -p "Chọn: " choice

    case "$choice" in
        1) install_ngosen ;;
        2) uninstall_ngosen ;;
        0) exit 0 ;;
        *) echo "Lựa chọn không hợp lệ." ;;
    esac
done
