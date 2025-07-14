# PicoTTS 编译问题修复方案

## 问题描述
在 Android 源码整体编译时，使用 `PRODUCT_PACKAGES += PicoTts` 方式编译，发现 system lib 目录没有生成项目相关的库文件（libttspico.so 和 libttscompat.so），但使用 `mmm external/svox/` 方式可以正常生成库文件。

## 问题分析
通过分析编译配置文件，发现以下问题：

1. **依赖关系缺失**：`PicoTts` 应用包虽然声明了 JNI 共享库依赖，但在产品配置中没有显式包含这些共享库
2. **编译顺序问题**：整体编译时可能存在编译顺序不当的情况
3. **产品配置不完整**：仅添加应用包到 PRODUCT_PACKAGES，缺少共享库的显式声明

## 解决方案

### 方案一：在产品配置中添加共享库依赖（推荐）

在您的产品配置文件（通常是 device makefile 或 product makefile）中，除了添加 `PicoTts` 应用包外，还需要显式添加其依赖的共享库：

```makefile
# 在产品配置文件中添加以下内容
PRODUCT_PACKAGES += \
    PicoTts \
    libttspico \
    libttscompat
```

### 方案二：修改 PicoTts 的 Android.mk 文件

修改 `pico/Android.mk` 文件，在 PicoTts 包的配置中添加 REQUIRED 声明：

```makefile
# 在 pico/Android.mk 中的 PicoTts 包配置部分添加
LOCAL_PACKAGE_NAME := PicoTts
LOCAL_MULTILIB := 32
LOCAL_PRIVATE_PLATFORM_APIS := true
LOCAL_REQUIRED_MODULES := libttspico libttscompat  # 添加这一行
LOCAL_SRC_FILES := \
    $(call all-java-files-under, src) \
    $(call all-java-files-under, compat)
```

### 方案三：创建一个包含所有组件的模块组

在根目录的 `Android.mk` 文件中创建一个包含所有组件的模块组：

```makefile
LOCAL_PATH:= $(call my-dir)

# 创建一个包含所有 PicoTTS 组件的模块组
include $(CLEAR_VARS)
LOCAL_MODULE := PicoTtsComplete
LOCAL_REQUIRED_MODULES := PicoTts libttspico libttscompat
include $(BUILD_PHONY_PACKAGE)

include $(LOCAL_PATH)/pico/Android.mk
```

然后在产品配置中使用：
```makefile
PRODUCT_PACKAGES += PicoTtsComplete
```

## 推荐实施步骤

1. **优先采用方案一**：这是最直接和标准的解决方案
2. **验证编译结果**：编译后检查 `out/target/product/[device]/system/lib/` 目录是否生成了 `libttspico.so` 和 `libttscompat.so`
3. **测试功能**：确保 TTS 功能正常工作

## 验证方法

编译完成后，可以通过以下方式验证：

```bash
# 检查共享库是否生成
ls -la out/target/product/[your_device]/system/lib/libtts*

# 检查语言资源是否正确拷贝
ls -la out/target/product/[your_device]/system/tts/lang_pico/

# 如果生成了 system.img，可以挂载检查
mkdir -p /tmp/system_mount
sudo mount -o loop out/target/product/[your_device]/system.img /tmp/system_mount
ls -la /tmp/system_mount/lib/libtts*
sudo umount /tmp/system_mount
```

## 补充说明

- `mmm external/svox/` 方式能成功的原因是它会编译整个目录下的所有模块，包括共享库
- 整体编译时使用 `PRODUCT_PACKAGES` 只会编译明确指定的模块，不会自动包含其依赖的共享库
- Android 编译系统需要显式声明所有要包含在最终系统镜像中的组件

这个解决方案应该能够解决您遇到的编译问题。建议优先尝试方案一，如果还有问题，可以结合使用其他方案。