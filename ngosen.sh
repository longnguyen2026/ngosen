
#!/usr/bin/env bash
# Ngó Sen Linux Tools
# Hỗ trợ: Kubuntu, Linux Mint và các hệ thống Ubuntu/Debian tương thích
# Nguồn chính thức: https://github.com/ngosen/ngosen
# License: GPL-3.0-or-later

set -uo pipefail

readonly PROJECT_URL="https://raw.githubusercontent.com/ngosen/ngosen/main/install.sh"
readonly PROJECT_NAME="Ngó Sen Linux Tools"

# Không chạy bằng sudo: trình cài đặt cần thiết lập cho tài khoản hiện tại.
if [[ "${EUID}" -eq 0 ]]; then
    echo "Không chạy script bằng sudo hoặc tài khoản root."
    echo "Hãy chạy bằng tài khoản người dùng bình thường."
    exit 1
fi

# Chỉ hỗ trợ hệ thống sử dụng APT và dpkg.
if [[ ! -r /etc/os-release ]] || ! command -v apt >/dev/null 2>&1; then
    echo "Không xác định được hệ thống Ubuntu/Debian tương thích."
    exit 1
fi

# shellcheck disable=SC1091
source /etc/os-release

case "${ID:-}" in
    ubuntu|linuxmint|neon|pop)
        ;;
    *)
        echo "Hệ điều hành chưa được script hỗ trợ: ${ID:-unknown}"
        echo "Script chỉ cho phép chạy trên Ubuntu, Kubuntu, Linux Mint,"
        echo "KDE neon hoặc Pop!_OS."
        exit 1
        ;;
esac

case "$(dpkg --print-architecture)" in
    amd64|arm64)
        ;;
    *)
        echo "Kiến trúc chưa được hỗ trợ: $(dpkg --print-architecture)"
        exit 1
        ;;
esac

if ! command -v curl >/dev/null 2>&1; then
    echo "Thiếu curl. Cài đặt bằng lệnh:"
    echo "sudo apt update && sudo apt install curl"
    exit 1
fi

pause() {
    echo
    read -r -p "Nhấn Enter để quay lại menu..." _
}

header() {
    clear 2>/dev/null || true
    echo "========================================"
    echo "       ${PROJECT_NAME}"
    echo "========================================"
    echo "Hệ điều hành : ${PRETTY_NAME:-$ID}"
    echo "Kiến trúc    : $(dpkg --print-architecture)"
    echo "Tài khoản    : ${USER:-$(id -un)}"
    echo "========================================"
}

get_installer() {
    local tmp
    tmp="$(mktemp)" || return 1

    echo "Đang tải trình cài đặt chính thức..." >&2
    if ! curl --fail --location --silent --show-error \
        --connect-timeout 15 --max-time 120 \
        "$PROJECT_URL" -o "$tmp"; then
        rm -f "$tmp"
        echo "Lỗi tải trình cài đặt. Kiểm tra kết nối Internet." >&2
        return 1
    fi

    if [[ ! -s "$tmp" ]] || ! head -n 1 "$tmp" | grep -q 'bash'; then
        rm -f "$tmp"
        echo "Tệp tải về không hợp lệ." >&2
        return 1
    fi

    printf '%s\n' "$tmp"
}

install_ngosen() {
    echo
    echo "CÀI ĐẶT / CẬP NHẬT NGÓ SEN"
    echo "Trình cài đặt chính thức sẽ hỏi xác nhận trước khi cài."
    echo "Nếu đang dùng Lotus, hãy đọc kỹ thông báo thay thế."
    echo
    read -r -p "Tiếp tục? [y/N]: " answer
    [[ "$answer" =~ ^[Yy]$ ]] || return 0

    local installer
    installer="$(get_installer)" || return 1

    # Không chạy bằng root để thiết lập đúng tài khoản đang đăng nhập.
    if bash "$installer"; then
        echo
        echo "Đã chạy xong trình cài đặt."
        echo "Nếu thành công, hãy làm theo hướng dẫn bên dưới."
        echo "KDE Wayland: đăng xuất rồi đăng nhập lại."
        echo "Cinnamon/X11: đăng xuất rồi đăng nhập lại nếu cần."
    else
        echo "Trình cài đặt báo lỗi. Hãy đọc thông báo phía trên."
        rm -f "$installer"
        return 1
    fi

    rm -f "$installer"
}

uninstall_ngosen() {
    echo
    echo "GỠ BỎ NGÓ SEN"
    echo "Sử dụng trình gỡ bỏ chính thức."
    echo "Cấu hình bộ gõ được giữ lại theo mặc định."
    echo "Fcitx5 và các bộ gõ khác không bị tự ý gỡ."
    echo
    read -r -p "Bạn có chắc muốn gỡ Ngó Sen? [y/N]: " answer
    [[ "$answer" =~ ^[Yy]$ ]] || return 0

    local installer
    installer="$(get_installer)" || return 1

    if bash "$installer" --uninstall; then
        echo
        echo "Đã chạy xong trình gỡ bỏ."
        echo "Hãy làm theo hướng dẫn đăng xuất/đăng nhập nếu được yêu cầu."
    else
        echo "Trình gỡ bỏ báo lỗi. Hãy đọc thông báo phía trên."
        rm -f "$installer"
        return 1
    fi

    rm -f "$installer"
}

check_status() {
    echo
    echo "KIỂM TRA TRẠNG THÁI"
    echo "--------------------"

    if dpkg-query -W -f='${Status}' fcitx5-ngosen 2>/dev/null |
        grep -q 'install ok installed'; then
        echo "Ngó Sen: ĐÃ CÀI"
        dpkg-query -W -f='Phiên bản: ${Version}\n' fcitx5-ngosen
    else
        echo "Ngó Sen: Chưa cài qua gói fcitx5-ngosen"
    fi

    if command -v fcitx5 >/dev/null 2>&1; then
        echo "Fcitx5: Đã có lệnh fcitx5"
    else
        echo "Fcitx5: Chưa tìm thấy lệnh fcitx5"
    fi

    if pgrep -u "$(id -u)" -x fcitx5 >/dev/null 2>&1; then
        echo "Tiến trình Fcitx5: Đang chạy"
    else
        echo "Tiến trình Fcitx5: Chưa chạy hoặc chạy theo cách khác"
    fi

    if [[ -d "$HOME/.config/fcitx5" ]]; then
        echo "Cấu hình Fcitx5: Có thư mục cấu hình"
    else
        echo "Cấu hình Fcitx5: Chưa có thư mục cấu hình"
    fi

    echo
    echo "Lưu ý: Trạng thái gói không xác nhận bộ gõ đã được"
    echo "thêm vào danh sách input method hay đã gõ được tiếng Việt."
}

restart_fcitx5() {
    echo
    echo "KHỞI ĐỘNG LẠI FCITX5"
    echo "Lưu ý: trên KDE Wayland, cách này có thể không đủ để"
    echo "các ứng dụng Qt nhận bộ gõ. Nên đăng xuất rồi đăng nhập lại."
    echo
    read -r -p "Thử chạy fcitx5 -rd? [y/N]: " answer
    [[ "$answer" =~ ^[Yy]$ ]] || return 0

    if command -v fcitx5 >/dev/null 2>&1; then
        fcitx5 -rd
        echo "Đã gửi lệnh khởi động lại Fcitx5."
    else
        echo "Không tìm thấy fcitx5. Hãy kiểm tra gói đã cài."
        return 1
    fi
}

desktop_help() {
    echo
    echo "HƯỚNG DẪN SAU KHI CÀI"
    echo "---------------------"

    case "${XDG_CURRENT_DESKTOP:-} ${DESKTOP_SESSION:-}" in
        *KDE*|*plasma*)
            echo "1. Mở System Settings."
            echo "2. Vào Keyboard → Virtual Keyboard."
            echo "3. Chọn Fcitx 5 nếu chưa chọn."
            echo "4. Đăng xuất rồi đăng nhập lại."
            ;;
        *X-Cinnamon*|*Cinnamon*|*cinnamon*)
            echo "1. Đăng xuất rồi đăng nhập lại nếu cần."
            echo "2. Mở Fcitx5 Configuration."
            echo "3. Thêm Ngó Sen vào danh sách bộ gõ."
            echo "4. Kiểm tra im-config nếu Fcitx5 chưa được chọn."
            ;;
        *)
            echo "Thiết lập Fcitx5 phù hợp với môi trường desktop của bạn."
            echo "KDE Wayland: chọn Fcitx 5 trong Virtual Keyboard."
            echo "Cinnamon/X11: kiểm tra cấu hình im-config."
            ;;
    esac

    echo "Phím chuyển bộ gõ mặc định thường là Ctrl+Space."
}

while true; do
    header
    echo "1. Cài đặt / cập nhật Ngó Sen"
    echo "2. Gỡ bỏ Ngó Sen"
    echo "3. Kiểm tra trạng thái"
    echo "4. Khởi động lại Fcitx5"
    echo "5. Hướng dẫn thiết lập sau cài đặt"
    echo "0. Thoát"
    echo "----------------------------------------"
    read -r -p "Chọn chức năng: " choice

    case "$choice" in
        1) install_ngosen; pause ;;
        2) uninstall_ngosen; pause ;;
        3) check_status; pause ;;
        4) restart_fcitx5; pause ;;
        5) desktop_help; pause ;;
        0) echo "Đã thoát."; exit 0 ;;
        *) echo "Lựa chọn không hợp lệ."; pause ;;
    esac
done
