#
# Installation of de-DE for the Pico TTS engine in the system image
# 
# Include this file in a product makefile to include the language files for de-DE
#
# Note the destination path matches that used in external/svox/pico/tts/com_svox_picottsengine.cpp
# 

#PRODUCT_COPY_FILES += \
#	external/svox/pico/lang/de-DE_gl0_sg.bin:system/tts/lang_pico/de-DE_gl0_sg.bin \
#	external/svox/pico/lang/de-DE_ta.bin:system/tts/lang_pico/de-DE_ta.bin
LOCAL_PATH:= $(call my-dir)
LOCAL_POST_PROCESS_COMMAND := $(shell mkdir -p $(TARGET_OUT)/tts/lang_pico)
LOCAL_POST_PROCESS_COMMAND := $(shell cp $(LOCAL_PATH)/de-DE_gl0_sg.bin $(TARGET_OUT)/tts/lang_pico/)
LOCAL_POST_PROCESS_COMMAND := $(shell cp $(LOCAL_PATH)/de-DE_ta.bin $(TARGET_OUT)/tts/lang_pico/)