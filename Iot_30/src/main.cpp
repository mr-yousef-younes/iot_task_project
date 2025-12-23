#include <Arduino.h>
#include <WiFi.h>
#include <DHT.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include "MAX30105.h"
#include <Wire.h>

#define DHTPIN 4
#define DHTTYPE DHT11

String deviceName = "ESP32-Pulse";

#define ENV_SERVICE_UUID "12345678-1234-1234-1234-1234567890ab"
#define ENV_MEASUREMENT_UUID "12345678-1234-1234-1234-1234567890ac"

#define HR_SERVICE_UUID "87654321-4321-4321-4321-ba0987654321"
#define HR_MEASUREMENT_UUID "87654321-4321-4321-4321-ba0987654322"

DHT dht(DHTPIN, DHTTYPE);
MAX30105 particleSensor;

BLECharacteristic *envCharacteristic;
BLECharacteristic *hrCharacteristic;
BLEServer *pServer;

bool deviceConnected = false;
bool oldDeviceConnected = false;

unsigned long lastEnvTime = 0;
unsigned long lastHrTime = 0;
const long envInterval = 2000;
const long hrInterval = 100;

class MyServerCallbacks : public BLEServerCallbacks
{
  void onConnect(BLEServer *pServer)
  {
    deviceConnected = true;
    Serial.println("Device Connected");
  }
  void onDisconnect(BLEServer *pServer)
  {
    deviceConnected = false;
    Serial.println("Device Disconnected");
  }
};

void setup()
{
  Serial.begin(115200);

  dht.begin();
  if (particleSensor.begin(Wire, I2C_SPEED_STANDARD))
  {
    particleSensor.setup();
    particleSensor.setPulseAmplitudeRed(0x0A);
    particleSensor.setPulseAmplitudeGreen(0);
    Serial.println("MAX30105 Initialized");
  }
  else
  {
    Serial.println("MAX30105 Not Found!");
  }

  BLEDevice::init(deviceName.c_str());
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *envService = pServer->createService(ENV_SERVICE_UUID);
  envCharacteristic = envService->createCharacteristic(
      ENV_MEASUREMENT_UUID,
      BLECharacteristic::PROPERTY_NOTIFY | BLECharacteristic::PROPERTY_READ);
  envCharacteristic->addDescriptor(new BLE2902());
  envService->start();

  BLEService *hrService = pServer->createService(HR_SERVICE_UUID);
  hrCharacteristic = hrService->createCharacteristic(
      HR_MEASUREMENT_UUID,
      BLECharacteristic::PROPERTY_NOTIFY | BLECharacteristic::PROPERTY_READ);
  hrCharacteristic->addDescriptor(new BLE2902());
  hrService->start();

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(ENV_SERVICE_UUID);
  pAdvertising->addServiceUUID(HR_SERVICE_UUID);
  pAdvertising->setScanResponse(false);
  pAdvertising->setMinPreferred(0x0);
  BLEDevice::startAdvertising();
  Serial.println("Waiting for a client connection...");
}

void loop()
{

  if (!deviceConnected && oldDeviceConnected)
  {
    delay(500);
    pServer->startAdvertising();
    Serial.println("Start advertising");
    oldDeviceConnected = deviceConnected;
  }
  if (deviceConnected && !oldDeviceConnected)
  {
    oldDeviceConnected = deviceConnected;
  }

  if (deviceConnected)
  {
    unsigned long currentMillis = millis();

    if (currentMillis - lastEnvTime >= envInterval)
    {
      float temp = dht.readTemperature();
      float hum = dht.readHumidity();

      if (!isnan(temp) && !isnan(hum))
      {

        int16_t tempInt = (int16_t)(temp * 100);
        int16_t humInt = (int16_t)(hum * 100);

        uint8_t envData[4];

        envData[0] = (tempInt >> 8) & 0xFF;
        envData[1] = tempInt & 0xFF;
        envData[2] = (humInt >> 8) & 0xFF;
        envData[3] = humInt & 0xFF;

        envCharacteristic->setValue(envData, 4);
        envCharacteristic->notify();

        lastEnvTime = currentMillis;
        Serial.printf("Sent Env: T=%.2f, H=%.2f\n", temp, hum);
      }
    }

    if (currentMillis - lastHrTime >= hrInterval)
    {
      long irValue = particleSensor.getIR();
      if (irValue > 50000)
      {
        uint32_t rawIR = (uint32_t)irValue;

        uint8_t hrData[4];
        hrData[0] = (rawIR >> 24) & 0xFF;
        hrData[1] = (rawIR >> 16) & 0xFF;
        hrData[2] = (rawIR >> 8) & 0xFF;
        hrData[3] = rawIR & 0xFF;

        hrCharacteristic->setValue(hrData, 4);
        hrCharacteristic->notify();

        Serial.printf("Sent HR Raw: %d\n", rawIR);
      }
      lastHrTime = currentMillis;
    }
  }
}