#include <Arduino.h>
#include <DHT.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <WiFi.h>
#include "MAX30105.h"

#define DHTPIN 4
#define DHTTYPE DHT11



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

class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *pServer) { deviceConnected = true; }
  void onDisconnect(BLEServer *pServer) { deviceConnected = false; }
};

class NameCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    std::string value = pCharacteristic->getValue();
    if (value.length() > 0) {
      deviceName = String(value.c_str());
      BLEDevice::deinit();
      BLEDevice::init(deviceName.c_str());
      pServer = BLEDevice::createServer();
      pServer->setCallbacks(new MyServerCallbacks());

      BLEService *envService = pServer->createService(ENV_SERVICE_UUID);
      envCharacteristic = envService->createCharacteristic(ENV_MEASUREMENT_UUID, BLECharacteristic::PROPERTY_NOTIFY);
      envCharacteristic->addDescriptor(new BLE2902());
      envService->start();

      BLEService *hrService = pServer->createService(HR_SERVICE_UUID);
      hrCharacteristic = hrService->createCharacteristic(HR_MEASUREMENT_UUID, BLECharacteristic::PROPERTY_NOTIFY);
      hrCharacteristic->addDescriptor(new BLE2902());
      hrService->start();

      nameCharacteristic = envService->createCharacteristic(DEVICE_NAME_CHAR_UUID, BLECharacteristic::PROPERTY_WRITE);
      nameCharacteristic->setCallbacks(new NameCallbacks());

      BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
      pAdvertising->addServiceUUID(ENV_SERVICE_UUID);
      pAdvertising->addServiceUUID(HR_SERVICE_UUID);
      pAdvertising->setScanResponse(true);
      pAdvertising->setMinPreferred(0x06);
      BLEDevice::startAdvertising();
    }
  }
};

void setup() {
  Serial.begin(115200);
  delay(500);
  dht.begin();

  BLEDevice::init(deviceName.c_str());
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *envService = pServer->createService(ENV_SERVICE_UUID);
  envCharacteristic = envService->createCharacteristic(ENV_MEASUREMENT_UUID, BLECharacteristic::PROPERTY_NOTIFY);
  envCharacteristic->addDescriptor(new BLE2902());
  envService->start();

  BLEService *hrService = pServer->createService(HR_SERVICE_UUID);
  if (particleSensor.begin(Wire, I2C_SPEED_STANDARD)) {
    hrCharacteristic = hrService->createCharacteristic(HR_MEASUREMENT_UUID, BLECharacteristic::PROPERTY_NOTIFY);
    hrCharacteristic->addDescriptor(new BLE2902());
    particleSensor.setup();
  }
  hrService->start();

  nameCharacteristic = envService->createCharacteristic(DEVICE_NAME_CHAR_UUID, BLECharacteristic::PROPERTY_WRITE);
  nameCharacteristic->setCallbacks(new NameCallbacks());

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(ENV_SERVICE_UUID);
  pAdvertising->addServiceUUID(HR_SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  BLEDevice::startAdvertising();
}

String makePayload(float tC, float h, float heatC) {
  char buf[128];
  snprintf(buf, sizeof(buf), "{\"tempC\":%.2f,\"hum\":%.1f,\"heatIndexC\":%.2f,\"ts\":\"%lu\"}", tC, h, heatC, millis());
  return String(buf);
}

unsigned long previousMillis = 0;
const long interval = 10000;

void loop() {
  unsigned long currentMillis = millis();
  if (currentMillis - previousMillis >= interval) {
    previousMillis = currentMillis;

    float tempC = dht.readTemperature();
    float hum = dht.readHumidity();
    if (!isnan(tempC) && !isnan(hum)) {
      float heatIndexC = dht.computeHeatIndex(tempC, hum, false);
      if (deviceConnected) {
        String payload = makePayload(tempC, hum, heatIndexC);
        std::string stdp = payload.c_str();
        envCharacteristic->setValue((uint8_t*)stdp.data(), stdp.length());
        envCharacteristic->notify();
      }
    }

    if (deviceConnected && particleSensor.begin(Wire, I2C_SPEED_STANDARD)) {
      long irValue = particleSensor.getIR();
      if (irValue > 50000) {
        String hrPayload = String(irValue);
        std::string stdHr = hrPayload.c_str();
        hrCharacteristic->setValue((uint8_t*)stdHr.data(), stdHr.length());
        hrCharacteristic->notify();
      }
    }
  }
}
