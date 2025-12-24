#include <Arduino.h>
#include <Wire.h>
#include <WiFi.h>
#include <DHT.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include "MAX30105.h"
#include "heartRate.h"
#include <Adafruit_NeoPixel.h>
#include <esp_task_wdt.h>

// --- الإعدادات والمنافذ ---
#define RGB_PIN 48
#define DHTPIN 4
#define DHTTYPE DHT11
#define WDT_TIMEOUT 10 // 10 ثواني للمراقب

Adafruit_NeoPixel rgbLed(1, RGB_PIN, NEO_GRB + NEO_KHZ800);
DHT dht(DHTPIN, DHTTYPE);
MAX30105 particleSensor;

// --- معرفات البلوتوث ---
const char *deviceName = "ESP-Pulse";
#define ENV_SERVICE_UUID "12345678-1234-1234-1234-1234567890ab"
#define ENV_MEASUREMENT_UUID "12345678-1234-1234-1234-1234567890ac"
#define HR_SERVICE_UUID "87654321-4321-4321-4321-ba0987654321"
#define HR_MEASUREMENT_UUID "87654321-4321-4321-4321-ba0987654322"

BLECharacteristic *envCharacteristic;
BLECharacteristic *hrCharacteristic;
BLEServer *pServer;

// --- متغيرات الحالة والتوقيت ---
bool deviceConnected = false;
bool oldDeviceConnected = false;
unsigned long lastEnvTime = 0;
unsigned long lastHrTime = 0;
unsigned long lastActivityTime = 0;
const long envInterval = 2000;
const long hrInterval = 100;
const long idleTimeout = 300000;
int bpmBuffer[4] = {0};
uint8_t bpmIndex = 0;

uint32_t currentColor = 0;
int beatAvg = 0;
long lastBeat = 0;
bool isLowPowerMode = false;

// --- كلاس إدارة اتصال البلوتوث ---
class MyServerCallbacks : public BLEServerCallbacks
{
    void onConnect(BLEServer *pServer)
    {
        deviceConnected = true;
        lastActivityTime = millis();
    }
    void onDisconnect(BLEServer *pServer)
    {
        deviceConnected = false;
    }
};

// --- وظائف إدارة الطاقة ---
void enterLowPowerMode()
{
    if (isLowPowerMode)
        return;
    setCpuFrequencyMhz(80);     // خفض التردد لتوفير الطاقة
    rgbLed.setPixelColor(0, 0); // إطفاء الإضاءة تماماً
    rgbLed.show();
    particleSensor.shutDown(); // إطفاء ليزر الحساس
    isLowPowerMode = true;
    Serial.println("System: Low Power Mode Active.");
}

void wakeUpSystem()
{
    if (!isLowPowerMode)
        return;
    setCpuFrequencyMhz(240); // العودة للقدرة الكاملة
    particleSensor.wakeUp();
    isLowPowerMode = false;
    Serial.println("System: Full Power Restored.");
}

void setup()
{
    Serial.begin(115200);

    // 1. استقرار الهاردوير والذاكرة
    esp_task_wdt_init(WDT_TIMEOUT, true);
    esp_task_wdt_add(NULL);

    // 2. توفير الطاقة: إطفاء الواي فاي تماماً
    WiFi.mode(WIFI_OFF);

    // 3. إعداد الليد
    rgbLed.begin();
    rgbLed.setBrightness(50);
    rgbLed.setPixelColor(0, rgbLed.Color(255, 0, 0)); // أحمر: بانتظار الاتصال
    rgbLed.show();

    // 4. إعداد الحساسات (I2C Stability)
    dht.begin();
    if (particleSensor.begin(Wire, I2C_SPEED_STANDARD))
    {
        particleSensor.setup();
        particleSensor.setPulseAmplitudeRed(0x0A);
        particleSensor.setPulseAmplitudeGreen(0);
    }

    // 5. إعداد البلوتوث (Security & Stability)
    BLEDevice::init(deviceName);
    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new MyServerCallbacks());

    BLEService *envService = pServer->createService(ENV_SERVICE_UUID);
    envCharacteristic = envService->createCharacteristic(ENV_MEASUREMENT_UUID, BLECharacteristic::PROPERTY_NOTIFY | BLECharacteristic::PROPERTY_READ);
    envCharacteristic->addDescriptor(new BLE2902());
    envService->start();

    BLEService *hrService = pServer->createService(HR_SERVICE_UUID);
    hrCharacteristic = hrService->createCharacteristic(HR_MEASUREMENT_UUID, BLECharacteristic::PROPERTY_NOTIFY | BLECharacteristic::PROPERTY_READ);
    hrCharacteristic->addDescriptor(new BLE2902());
    hrService->start();

    BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(ENV_SERVICE_UUID);
    pAdvertising->addServiceUUID(HR_SERVICE_UUID);
    BLEDevice::startAdvertising();

    lastActivityTime = millis();
}

void loop()
{
    esp_task_wdt_reset(); // إعادة ضبط المراقب الذكي
    unsigned long currentMillis = millis();

    // إدارة إعادة البث
    if (!deviceConnected && oldDeviceConnected)
    {
        delay(500);
        pServer->startAdvertising();
        oldDeviceConnected = deviceConnected;
    }
    if (deviceConnected && !oldDeviceConnected)
    {
        wakeUpSystem();
        oldDeviceConnected = deviceConnected;
    }

    // إدارة وضع الخمول (بعد 5 دقائق)
    if (!deviceConnected && (currentMillis - lastActivityTime > idleTimeout))
    {
        enterLowPowerMode();
    }

    bool sentEnv = false;
    bool sentHr = false;

    if (deviceConnected)
    {
        lastActivityTime = currentMillis; // تحديث وقت النشاط

        // --- معالجة الحساس البيئي (DHT) ---
        if (currentMillis - lastEnvTime >= envInterval)
        {
            float temp = dht.readTemperature();
            float hum = dht.readHumidity();
            int16_t tempInt, humInt;

            if (!isnan(temp) && !isnan(hum))
            {
                tempInt = (int16_t)(temp * 100);
                humInt = (int16_t)(hum * 100);
                sentEnv = true;
            }
            else
            {
                // القيم الوهمية (Null Representation): -999 للحرارة
                tempInt = -999;
                humInt = -999;
            }

            uint8_t envData[4] = {
                (uint8_t)((tempInt >> 8) & 0xFF), (uint8_t)(tempInt & 0xFF),
                (uint8_t)((humInt >> 8) & 0xFF), (uint8_t)(humInt & 0xFF)};
            envCharacteristic->setValue(envData, 4);
            envCharacteristic->notify();
            lastEnvTime = currentMillis;
        }

        // --- معالجة حساس النبض (MAX30105) ---
        long irValue = particleSensor.getIR();

        if (irValue > 50000)
        { // استشعار وجود إصبع (Auto Wake-up)
            if (checkForBeat(irValue))
            {
                long delta = millis() - lastBeat;
                lastBeat = millis();
                float bpm = 60 / (delta / 1000.0);
                if (bpm < 190 && bpm > 55)
                {
                    bpmBuffer[bpmIndex++] = (int)bpm;
                    bpmIndex %= 4;

                    int sum = 0;
                    for (int i = 0; i < 4; i++)
                        sum += bpmBuffer[i];
                    beatAvg = sum / 4;
                }
            }
        }
        else
        {
            beatAvg = -1; // القيم الوهمية (Null): -1 عند غياب الإصبع (Data Filtering)
        }

        if (currentMillis - lastHrTime >= hrInterval)
        {
            int32_t hrToSend = (int32_t)beatAvg;
            uint8_t hrData[4] = {
                (uint8_t)((hrToSend >> 24) & 0xFF), (uint8_t)((hrToSend >> 16) & 0xFF),
                (uint8_t)((hrToSend >> 8) & 0xFF), (uint8_t)(hrToSend & 0xFF)};
            hrCharacteristic->setValue(hrData, 4);
            hrCharacteristic->notify();
            if (beatAvg > 0)
                sentHr = true;
            lastHrTime = currentMillis;
        }
    }

    // --- نظام تعبير الألوان الاحترافي ---
    uint32_t newColor;
    if (!deviceConnected)
    {
        newColor = isLowPowerMode ? 0 : rgbLed.Color(255, 0, 0); // أحمر
    }
    else if (sentEnv && sentHr)
    {
        newColor = rgbLed.Color(0, 255, 0); // أخضر: بيانات كاملة وسليمة
    }
    else if (sentEnv)
    {
        newColor = rgbLed.Color(255, 165, 0); // برتقالي: حرارة فقط
    }
    else if (sentHr)
    {
        newColor = rgbLed.Color(128, 0, 128); // بنفسجي: نبض فقط
    }
    else
    {
        newColor = rgbLed.Color(255, 255, 0); // أصفر: متصل بدون قراءة حقيقية
    }

    if (newColor != currentColor)
    {
        rgbLed.setPixelColor(0, newColor);
        rgbLed.show();
        currentColor = newColor;
    }
}