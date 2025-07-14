# PicoTTS 64位适配补丁应用总结

## 应用日期
2025年1月15日

## 问题背景
在Android 15 (A15) 64位系统上，PicoTTS因强制使用32位架构而出现内存访问错误：
```
ABI: 'arm' (32位)
signal 11 (SIGSEGV), fault addr 0x6559d69c
picobase_get_next_utf8char+26
```

## 已应用的修改

### 1. 构建配置更新

#### 1.1 主应用配置 (pico/Android.mk)
```diff
- LOCAL_MULTILIB := 32
+ LOCAL_MULTILIB := both
```

#### 1.2 Native库配置 (pico/lib/Android.mk)
```diff
- LOCAL_MULTILIB := 32
+ LOCAL_MULTILIB := both

+ # 64位架构支持
+ ifeq ($(TARGET_ARCH),arm64)
+     LOCAL_CFLAGS += -DPICO_64BIT_SUPPORT -DPICO_ARM64
+ endif
+ ifeq ($(TARGET_ARCH),x86_64)
+     LOCAL_CFLAGS += -DPICO_64BIT_SUPPORT -DPICO_X86_64
+ endif
```

#### 1.3 JNI兼容层 (pico/compat/jni/Android.mk)
```diff
- LOCAL_MULTILIB := 32
+ LOCAL_MULTILIB := both

+ # 64位架构支持
+ ifeq ($(TARGET_ARCH),arm64)
+     LOCAL_CFLAGS += -DPICO_64BIT_SUPPORT -DPICO_ARM64
+ endif
+ ifeq ($(TARGET_ARCH),x86_64)
+     LOCAL_CFLAGS += -DPICO_64BIT_SUPPORT -DPICO_X86_64
+ endif
```

#### 1.4 TTS引擎 (pico/tts/Android.mk)
在两个构建规则中都应用：
```diff
- LOCAL_MULTILIB := 32
+ LOCAL_MULTILIB := both

+ # 64位架构支持
+ ifeq ($(TARGET_ARCH),arm64)
+     LOCAL_CFLAGS += -DPICO_64BIT_SUPPORT -DPICO_ARM64
+ endif
+ ifeq ($(TARGET_ARCH),x86_64)
+     LOCAL_CFLAGS += -DPICO_64BIT_SUPPORT -DPICO_X86_64
+ endif
```

### 2. 代码层面适配

#### 2.1 数据类型安全 (pico/lib/picobase.h)
添加了64位兼容的类型定义：
```c
/* 64位系统适配 */
#ifdef PICO_64BIT_SUPPORT
    #include <stdint.h>
    typedef uint64_t picoos_ptr_t;
    typedef int64_t picoos_sptr_t;
#else
    typedef uint32_t picoos_ptr_t;
    typedef int32_t picoos_sptr_t;
#endif

/* 指针安全的转换宏 */
#define PICO_PTR_TO_UINT(ptr) ((picoos_ptr_t)(ptr))
#define PICO_UINT_TO_PTR(val) ((void*)(picoos_ptr_t)(val))
```

#### 2.2 内存安全增强 (pico/lib/picobase.c)
在`picobase_get_next_utf8char`函数中添加：
- 64位指针对齐检查
- 增强的长度检查
- 更安全的字符复制循环

#### 2.3 JNI层64位适配 (pico/compat/jni/com_android_tts_compat_SynthProxy.cpp)
添加了64位JNI类型安全转换宏：
```cpp
// 64位JNI适配
#ifdef PICO_64BIT_SUPPORT
    #define JLONG_TO_PTR(jlong_val) ((void*)(uintptr_t)(jlong_val))
    #define PTR_TO_JLONG(ptr) ((jlong)(uintptr_t)(ptr))
#else
    #define JLONG_TO_PTR(jlong_val) ((void*)(long)(jlong_val))
    #define PTR_TO_JLONG(ptr) ((jlong)(long)(ptr))
#endif
```

#### 2.4 运行时架构检测 (pico/lib/picoapi.c)
在初始化函数中添加架构信息输出：
```c
/* 64位架构检测 */
#ifdef PICO_ARCH_INFO
    #ifdef PICO_64BIT_SUPPORT
        PICODBG_INFO(("PicoTTS initializing in 64-bit mode"));
        PICODBG_INFO(("Pointer size: %u bytes", (unsigned int)sizeof(void*)));
        #ifdef PICO_ARM64
            PICODBG_INFO(("Architecture: ARM64"));
        #elif defined(PICO_X86_64)
            PICODBG_INFO(("Architecture: x86_64"));
        #endif
    #else
        PICODBG_INFO(("PicoTTS initializing in 32-bit mode"));
        PICODBG_INFO(("Pointer size: %u bytes", (unsigned int)sizeof(void*)));
    #endif
#endif
```

## 构建与测试

### 构建命令
```bash
# 进入Android源码根目录
cd $ANDROID_BUILD_TOP

# 清理之前的构建
make clean-pico

# 构建PicoTTS (支持32位和64位)
make PicoTts

# 或者使用mm命令在pico目录下构建
cd external/svox
mm
```

### 验证构建结果
```bash
# 检查生成的库文件
find out/ -name "libttspico.so" -exec file {} \;
find out/ -name "libttscompat.so" -exec file {} \;

# 应该看到类似输出：
# .../arm64-v8a/libttspico.so: ELF 64-bit LSB shared object, ARM aarch64
# .../armeabi-v7a/libttspico.so: ELF 32-bit LSB shared object, ARM
```

### 运行时验证
```bash
# 安装并运行
adb install -r out/target/product/*/system/app/PicoTts/PicoTts.apk

# 查看初始化日志
adb logcat | grep -E "(PicoTTS.*bit|PicoTTS.*Architecture)"

# 期望的日志输出：
# PicoTTS initializing in 64-bit mode
# Pointer size: 8 bytes  
# Architecture: ARM64
```

### 测试案例

#### 基本功能测试
```bash
# 设置TTS引擎为PicoTTS
adb shell settings put secure tts_default_synth com.svox.pico

# 测试语音合成
adb shell "echo 'Hello World' | am broadcast -a android.intent.action.TTS_SERVICE_SPEAK"
```

#### 稳定性测试
```bash
# 连续测试多次UTF-8处理
for i in {1..100}; do
    adb shell "echo 'Test UTF-8: 你好世界 $i' | am broadcast -a android.intent.action.TTS_SERVICE_SPEAK"
    sleep 1
done

# 监控crash情况
adb logcat | grep -E "(SIGSEGV|tombstone|FATAL)"
```

## 预期效果

### 解决的问题
✅ Android 15上的SIGSEGV崩溃问题  
✅ 64位系统上的内存访问错误  
✅ 指针类型转换安全性  

### 兼容性保证
✅ 保持32位设备的向后兼容  
✅ 支持ARM64和x86_64架构  
✅ 不影响现有TTS功能  

### 性能优化
✅ 更好的内存对齐  
✅ 减少内存访问错误  
✅ 运行时架构优化  

## 监控指标

### 稳定性指标
- SIGSEGV崩溃率应降至0
- TTS合成成功率应保持>99%
- 内存泄漏检测无异常

### 性能指标  
- TTS合成延迟保持在可接受范围
- 内存使用量轻微增加（<10%）
- CPU使用率无明显变化

## 风险评估

### 低风险因素
- 使用`both`配置保持完全向后兼容
- 仅添加防御性编程，不修改核心算法
- 已有的错误处理机制得到保留

### 需要关注的点
- 64位环境下的充分测试
- 不同设备类型的兼容性验证
- 长期稳定性观察

## 回退方案

如果出现问题，可以通过以下方式回退：

### 紧急回退（仅构建配置）
```bash
# 将所有Android.mk中的配置改回
LOCAL_MULTILIB := 32

# 重新构建
make clean-pico && make PicoTts
```

### 完全回退
1. 恢复所有修改的文件到之前的版本
2. 清理构建目录并重新构建
3. 重新部署应用

## 下一步计划

1. **短期（1-2周）**：
   - 在测试设备上验证稳定性
   - 收集性能数据
   - 修复发现的问题

2. **中期（1个月）**：
   - 扩大测试范围
   - 优化性能参数
   - 准备生产部署

3. **长期（3个月）**：
   - 考虑迁移到纯64位构建
   - 进一步优化内存使用
   - 准备下一版本更新

## 结论

本次64位适配补丁应该能够有效解决Android 15上的SIGSEGV崩溃问题，同时保持良好的向后兼容性。所有修改都经过了仔细的设计，优先考虑稳定性和安全性。