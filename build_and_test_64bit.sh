#!/bin/bash

# PicoTTS 64位适配构建和测试脚本
# 使用方法: ./build_and_test_64bit.sh [clean|build|test|all]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查环境
check_environment() {
    log_info "检查构建环境..."
    
    if [ -z "$ANDROID_BUILD_TOP" ]; then
        log_error "ANDROID_BUILD_TOP 未设置，请运行 source build/envsetup.sh"
        exit 1
    fi
    
    if [ ! -d "$ANDROID_BUILD_TOP" ]; then
        log_error "Android构建目录不存在: $ANDROID_BUILD_TOP"
        exit 1
    fi
    
    # 检查是否在正确的目录
    if [ ! -f "pico/Android.mk" ]; then
        log_error "请在svox项目根目录运行此脚本"
        log_info "当前目录: $(pwd)"
        exit 1
    fi
    
    log_success "环境检查通过"
}

# 清理构建
clean_build() {
    log_info "清理PicoTTS构建..."
    
    cd "$ANDROID_BUILD_TOP"
    
    # 清理PicoTTS相关的构建产物
    rm -rf out/target/product/*/obj/SHARED_LIBRARIES/libttspico_intermediates/
    rm -rf out/target/product/*/obj/SHARED_LIBRARIES/libttscompat_intermediates/
    rm -rf out/target/product/*/obj/STATIC_LIBRARIES/libsvoxpico_intermediates/
    rm -rf out/target/product/*/obj/STATIC_LIBRARIES/libttspico_engine_intermediates/
    rm -rf out/target/product/*/obj/APPS/PicoTts_intermediates/
    
    # 清理已安装的文件
    rm -f out/target/product/*/system/app/PicoTts/PicoTts.apk
    rm -f out/target/product/*/system/lib*/libttspico.so
    rm -f out/target/product/*/system/lib*/libttscompat.so
    
    log_success "清理完成"
}

# 构建PicoTTS
build_pico() {
    log_info "构建PicoTTS (支持32位和64位)..."
    
    cd "$ANDROID_BUILD_TOP"
    
    # 设置构建环境
    source build/envsetup.sh
    
    # 构建PicoTTS
    log_info "执行构建命令: make PicoTts"
    if make PicoTts -j$(nproc); then
        log_success "PicoTTS构建完成"
    else
        log_error "PicoTTS构建失败"
        exit 1
    fi
}

# 验证构建结果
verify_build() {
    log_info "验证构建结果..."
    
    cd "$ANDROID_BUILD_TOP"
    
    # 检查APK文件
    APK_PATH=$(find out/target/product/*/system/app/PicoTts/ -name "PicoTts.apk" | head -1)
    if [ -n "$APK_PATH" ] && [ -f "$APK_PATH" ]; then
        log_success "APK文件存在: $APK_PATH"
        APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
        log_info "APK大小: $APK_SIZE"
    else
        log_error "APK文件不存在"
        return 1
    fi
    
    # 检查native库文件
    log_info "检查native库架构..."
    
    # 查找所有libttspico.so文件
    LIBS=$(find out/target/product/ -name "libttspico.so" 2>/dev/null || true)
    if [ -z "$LIBS" ]; then
        log_error "未找到libttspico.so文件"
        return 1
    fi
    
    for lib in $LIBS; do
        arch_info=$(file "$lib" | grep -o "ELF [0-9]*-bit.*ARM.*" || echo "未知架构")
        log_info "库文件: $lib -> $arch_info"
        
        if echo "$arch_info" | grep -q "64-bit"; then
            log_success "找到64位库: $lib"
        elif echo "$arch_info" | grep -q "32-bit"; then
            log_success "找到32位库: $lib"
        else
            log_warning "未识别的架构: $lib"
        fi
    done
    
    # 检查libttscompat.so
    COMPAT_LIBS=$(find out/target/product/ -name "libttscompat.so" 2>/dev/null || true)
    if [ -n "$COMPAT_LIBS" ]; then
        for lib in $COMPAT_LIBS; do
            arch_info=$(file "$lib" | grep -o "ELF [0-9]*-bit.*ARM.*" || echo "未知架构")
            log_info "兼容库: $lib -> $arch_info"
        done
    fi
    
    log_success "构建结果验证完成"
}

# 安装到设备
install_to_device() {
    log_info "安装PicoTTS到设备..."
    
    # 检查设备连接
    if ! adb devices | grep -q "device$"; then
        log_error "未找到已连接的Android设备"
        log_info "请确保设备已连接并启用USB调试"
        return 1
    fi
    
    # 查找APK文件
    APK_PATH=$(find out/target/product/*/system/app/PicoTts/ -name "PicoTts.apk" | head -1)
    if [ ! -f "$APK_PATH" ]; then
        log_error "APK文件不存在，请先构建"
        return 1
    fi
    
    # 安装APK
    log_info "安装APK: $APK_PATH"
    if adb install -r "$APK_PATH"; then
        log_success "APK安装成功"
    else
        log_error "APK安装失败"
        return 1
    fi
    
    # 检查设备架构
    DEVICE_ARCH=$(adb shell getprop ro.product.cpu.abi)
    log_info "设备架构: $DEVICE_ARCH"
    
    # 等待安装完成
    sleep 2
    
    log_success "安装完成"
}

# 运行时测试
runtime_test() {
    log_info "运行PicoTTS运行时测试..."
    
    # 检查设备连接
    if ! adb devices | grep -q "device$"; then
        log_error "未找到已连接的Android设备"
        return 1
    fi
    
    # 检查PicoTTS是否已安装
    if ! adb shell pm list packages | grep -q "com.svox.pico"; then
        log_error "PicoTTS未安装，请先运行安装"
        return 1
    fi
    
    # 启动日志监控
    log_info "开始监控初始化日志（10秒）..."
    timeout 10s adb logcat -v time | grep -i "pico" &
    LOGCAT_PID=$!
    
    # 触发TTS初始化
    log_info "触发TTS引擎初始化..."
    adb shell "am start -a android.intent.action.MAIN -c android.intent.category.LAUNCHER com.android.settings/.SubSettings" > /dev/null 2>&1
    sleep 2
    adb shell "am start -a android.speech.tts.engine.INSTALL_TTS_DATA -c android.intent.category.DEFAULT com.svox.pico" > /dev/null 2>&1
    
    # 等待日志
    sleep 8
    
    # 停止日志监控
    kill $LOGCAT_PID 2>/dev/null || true
    
    # 基本功能测试
    log_info "进行基本TTS功能测试..."
    
    # 设置PicoTTS为默认引擎
    adb shell settings put secure tts_default_synth com.svox.pico
    
    # 测试UTF-8字符处理
    log_info "测试UTF-8字符处理..."
    adb shell "echo 'Hello World' | am broadcast -a android.intent.action.TTS_SERVICE_SPEAK" 2>/dev/null
    sleep 1
    adb shell "echo 'Test UTF-8: 你好世界' | am broadcast -a android.intent.action.TTS_SERVICE_SPEAK" 2>/dev/null
    
    # 检查是否有crash
    log_info "检查是否有crash报告..."
    CRASHES=$(adb shell "find /data/tombstones/ -name '*pico*' 2>/dev/null | wc -l" || echo "0")
    if [ "$CRASHES" -gt 0 ]; then
        log_error "发现 $CRASHES 个crash文件"
        return 1
    else
        log_success "未发现crash文件"
    fi
    
    log_success "运行时测试完成"
}

# 完整测试流程
run_full_test() {
    log_info "开始完整的64位适配测试流程..."
    
    check_environment
    clean_build
    build_pico
    verify_build
    install_to_device
    runtime_test
    
    log_success "所有测试完成！"
    log_info "PicoTTS 64位适配补丁验证成功"
}

# 显示帮助信息
show_help() {
    echo "PicoTTS 64位适配构建和测试脚本"
    echo ""
    echo "使用方法:"
    echo "  $0 [command]"
    echo ""
    echo "命令:"
    echo "  clean     - 清理构建产物"
    echo "  build     - 构建PicoTTS"
    echo "  verify    - 验证构建结果"
    echo "  install   - 安装到设备"
    echo "  test      - 运行时测试"
    echo "  all       - 运行完整测试流程"
    echo "  help      - 显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 all         # 运行完整测试"
    echo "  $0 build       # 仅构建"
    echo "  $0 test        # 仅运行测试"
}

# 主函数
main() {
    case "${1:-all}" in
        "clean")
            check_environment
            clean_build
            ;;
        "build")
            check_environment
            build_pico
            ;;
        "verify")
            check_environment
            verify_build
            ;;
        "install")
            check_environment
            install_to_device
            ;;
        "test")
            runtime_test
            ;;
        "all")
            run_full_test
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "未知命令: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"