#include <Arduino.h>
#include <WiFi.h>
#include <DHT.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include "MAX30105.h"
#define DHTPIN 4
#define DHTTYPE DHT11

String deviceName = "ESP32-S3";

#define ENV_SERVICE_UUID "12345678-1234-1234-1234-1234567890ab"
#define ENV_MEASUREMENT_UUID "12345678-1234-1234-1234-1234567890ac"
#define HR_SERVICE_UUID "87654321-4321-4321-4321-ba0987654321"
#define HR_MEASUREMENT_UUID "87654321-4321-4321-4321-ba0987654322"
#define DEVICE_NAME_CHAR_UUID "0000ff01-0000-1000-8000-00805f9b34fb"

DHT dht(DHTPIN, DHTTYPE);
BLECharacteristic *envCharacteristic;
BLECharacteristic *hrCharacteristic;
BLECharacteristic *nameCharacteristic;
BLEServer *pServer;
MAX30105 particleSensor;
bool deviceConnected = false;

class MyServerCallbacks : public BLEServerCallbacks
{
  void onConnect(BLEServer *pServer)
  {
    deviceConnected = true;
    Serial.println("Connected to Phone");
  }
  void onDisconnect(BLEServer *pServer)
  {
    deviceConnected = false;
    Serial.println("Disconnected from Phone");
    BLEDevice::startAdvertising(); 
  }
};
class NameCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    std::string value = pCharacteristic->getValue();
    if (value.length() > 0) {
      Serial.print("New Device Name: ");
      Serial.println(value.c_str());
      // ملاحظة: تغيير الاسم الفعلي يتطلب إعادة تشغيل الجهاز 
      // يفضل تخزينه في الـ EEPROM وعمل restart
    }
  }
};

void setup() {
  Serial.begin(115200);
  delay(1000);
  dht.begin();

  // 1. تهيئة البلوتوث
  BLEDevice::init(deviceName.c_str());
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // 2. إنشاء خدمة البيئة المستقلة (DHT11)
  BLEService *envService = pServer->createService(ENV_SERVICE_UUID);
  envCharacteristic = envService->createCharacteristic(
                        ENV_MEASUREMENT_UUID, 
                        BLECharacteristic::PROPERTY_NOTIFY | BLECharacteristic::PROPERTY_READ
                      );
  envCharacteristic->addDescriptor(new BLE2902());
  
  // خاصية الاسم داخل خدمة البيئة لتوحيد الهيكل
  nameCharacteristic = envService->createCharacteristic(
                         DEVICE_NAME_CHAR_UUID, 
                         BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_READ
                       );
  nameCharacteristic->setCallbacks(new NameCallbacks());
  envService->start();

  BLEService *hrService = pServer->createService(HR_SERVICE_UUID);
  hrCharacteristic = hrService->createCharacteristic(
                       HR_MEASUREMENT_UUID, 
                       BLECharacteristic::PROPERTY_NOTIFY | BLECharacteristic::PROPERTY_READ
                     );
  hrCharacteristic->addDescriptor(new BLE2902());

  if (particleSensor.begin(Wire, I2C_SPEED_STANDARD)) {
    particleSensor.setup();
    Serial.println("MAX30105 Initialized Successfully");
  } else {
    Serial.println("Warning: MAX30105 not found. Service will still be visible.");
  }
  hrService->start();

  // 4. إعدادات البث (Advertising)
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(ENV_SERVICE_UUID);
  pAdvertising->addServiceUUID(HR_SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);  
  BLEDevice::startAdvertising();
  Serial.println("Bluetooth is Ready and Independent");
}

String makePayload(float t, float h, float hi) {
  char buf[128];
  
  snprintf(buf, sizeof(buf), "{\"t\":%.1f,\"h\":%.1f,\"i\":%.1f}", t, h, hi);
  return String(buf);
}
 
unsigned long previousMillis = 0;
const long interval = 3500; 

void loop() {
  if (deviceConnected) {
    unsigned long currentMillis = millis();
    if (currentMillis - previousMillis >= interval) {
      previousMillis = currentMillis;

      // --- إرسال بيانات الحرارة بشكل مستقل ---
      float tempC = dht.readTemperature();
      float hum = dht.readHumidity();
      if (!isnan(tempC) && !isnan(hum)) {
        float heatIndexC = dht.computeHeatIndex(tempC, hum, false);
        String payload = makePayload(tempC, hum, heatIndexC);
        envCharacteristic->setValue(payload.c_str());
        envCharacteristic->notify();
        Serial.println("Env Data Sent: " + payload);
      }

      // --- إرسال بيانات النبض بشكل مستقل ---
      long irValue = particleSensor.getIR();
      if (irValue > 50000) { // يرسل فقط إذا استشعر وجود إصبع
        String hrPayload = String(irValue);
        hrCharacteristic->setValue(hrPayload.c_str());
        hrCharacteristic->notify();
        Serial.println("Heart Rate Sent: " + hrPayload);
      }
    }
  }
}