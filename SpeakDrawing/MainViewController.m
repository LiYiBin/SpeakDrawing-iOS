//
//  MainViewController.m
//  SpeakDrawing
//
//  Created by YiBin on 2014/6/11.
//  Copyright (c) 2014年 YB. All rights reserved.
//

#import "MainViewController.h"

#import <CoreBluetooth/CoreBluetooth.h>
#import <OpenEars/LanguageModelGenerator.h>
#import <OpenEars/AcousticModel.h>
#import <OpenEars/PocketsphinxController.h>
#import <OpenEars/OpenEarsEventsObserver.h>

#define kInit 0x00
#define kChangeSingleLedColor 0x01

#define RBL_SERVICE_UUID @"713D0000-503E-4C75-BA94-3148F18D941E"
#define RBL_CHAR_TX_UUID @"713D0002-503E-4C75-BA94-3148F18D941E"
#define RBL_CHAR_RX_UUID @"713D0003-503E-4C75-BA94-3148F18D941E"
#define RBL_BLE_FRAMEWORK_VER 0x0200

@interface MainViewController () <OpenEarsEventsObserverDelegate, CBCentralManagerDelegate, CBPeripheralDelegate>

- (IBAction)touchDownMicrophone:(id)sender;
- (IBAction)touchUpMicrophone:(id)sender;

// for speech recognition
@property (strong, nonatomic) LanguageModelGenerator *languageModelGenerator;
@property (strong, nonatomic) PocketsphinxController *pocketspinxController;
@property (strong, nonatomic) OpenEarsEventsObserver *openEarsEventsObserver;

@property (strong, nonatomic) NSString *modelPath;
@property (strong, nonatomic) NSString *lmPath;
@property (strong, nonatomic) NSString *dicPath;

- (void)setupSpeechRecognition;

// for bluetooth
@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) CBPeripheral *activePeripheral;

// for effect
- (void)sendLedDataByBLE:(NSData *)data;
- (void)sendInit;
- (void)sendSingleLedColorByBLE:(int)led red:(int)red green:(int)green blue:(int)blue;

@end

@implementation MainViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // setup background
    self.view.backgroundColor = [[UIColor alloc] initWithPatternImage:[UIImage imageNamed:@"Background1"]];

    // setup for bluetooth
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:@{CBConnectPeripheralOptionNotifyOnNotificationKey: @YES}];
    
    [self setupSpeechRecognition];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Speech Recognition

- (void)setupSpeechRecognition
{
    self.languageModelGenerator = [[LanguageModelGenerator alloc] init];
    
    NSArray *words = @[@"WORD", @"HELLO", @"GO"];
    NSString *name = @"EmotionGrammars";
    self.modelPath = [AcousticModel pathToModel:@"AcousticModelEnglish"];
    
    NSError *error = [self.languageModelGenerator generateLanguageModelFromArray:words withFilesNamed:name forAcousticModelAtPath:self.modelPath];
    
    NSDictionary *languageGeneratorResults = nil;
    
    if ([error code] == noErr) {
        
        languageGeneratorResults = [error userInfo];
        
        self.lmPath = [languageGeneratorResults objectForKey:@"LMPath"];
        self.dicPath = [languageGeneratorResults objectForKey:@"DictionaryPath"];
        NSLog(@"Result: %@", languageGeneratorResults);
        
    } else {
        NSLog(@"Language Model Generator of OpenEars's Error: %@", [error localizedDescription]);
    }
    
    self.pocketspinxController = [[PocketsphinxController alloc] init];
    
    //    self.pocketspinxController.verbosePocketSphinx = true; // for debug
    self.pocketspinxController.outputAudio = true;
    self.pocketspinxController.returnNbest = true;
    self.pocketspinxController.nBestNumber = 5;
    
    self.openEarsEventsObserver = [[OpenEarsEventsObserver alloc] init];
    self.openEarsEventsObserver.delegate = self;
}

#pragma mark IBAction for Speech Recognition

- (IBAction)touchDownMicrophone:(id)sender
{
    [self.pocketspinxController startListeningWithLanguageModelAtPath:self.lmPath dictionaryAtPath:self.dicPath acousticModelAtPath:self.modelPath languageModelIsJSGF:false];
}

- (IBAction)touchUpMicrophone:(id)sender
{
    [self.pocketspinxController stopListening];
}

#pragma mark OpenEarsEventsObserverDelegate

- (void) pocketsphinxDidReceiveHypothesis:(NSString *)hypothesis recognitionScore:(NSString *)recognitionScore utteranceID:(NSString *)utteranceID {
	NSLog(@"The received hypothesis is %@ with a score of %@ and an ID of %@", hypothesis, recognitionScore, utteranceID);
}

- (void) pocketsphinxDidStartCalibration {
	NSLog(@"Pocketsphinx calibration has started.");
}

- (void) pocketsphinxDidCompleteCalibration {
	NSLog(@"Pocketsphinx calibration is complete.");
}

- (void) pocketsphinxDidStartListening {
	NSLog(@"Pocketsphinx is now listening.");
}

- (void) pocketsphinxDidDetectSpeech {
	NSLog(@"Pocketsphinx has detected speech.");
}

- (void) pocketsphinxDidDetectFinishedSpeech {
	NSLog(@"Pocketsphinx has detected a period of silence, concluding an utterance.");
}

- (void) pocketsphinxDidStopListening {
	NSLog(@"Pocketsphinx has stopped listening.");
}

- (void) pocketsphinxDidSuspendRecognition {
	NSLog(@"Pocketsphinx has suspended recognition.");
}

- (void) pocketsphinxDidResumeRecognition {
	NSLog(@"Pocketsphinx has resumed recognition.");
}

- (void) pocketsphinxDidChangeLanguageModelToFile:(NSString *)newLanguageModelPathAsString andDictionary:(NSString *)newDictionaryPathAsString {
	NSLog(@"Pocketsphinx is now using the following language model: \n%@ and the following dictionary: %@",newLanguageModelPathAsString,newDictionaryPathAsString);
}

- (void) pocketSphinxContinuousSetupDidFail { // This can let you know that something went wrong with the recognition loop startup. Turn on OPENEARSLOGGING to learn why.
	NSLog(@"Setting up the continuous recognition loop has failed for some reason, please turn on OpenEarsLogging to learn more.");
}
- (void) testRecognitionCompleted {
	NSLog(@"A test file that was submitted for recognition is now complete.");
}

#pragma mark - Core Bluetooth
#pragma mark CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    NSLog(@"Central Manager did update state: %@", [central description]);
    if (central.state != CBCentralManagerStatePoweredOn) {
        return;
    }
    
    [central scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:RBL_SERVICE_UUID]] options:nil];
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSLog(@"Dicovered peripheral: %@", peripheral.identifier);
    if (self.activePeripheral != peripheral) {
        self.activePeripheral = peripheral;
        self.activePeripheral.delegate = self;
        
        [central connectPeripheral:peripheral options:@{CBConnectPeripheralOptionNotifyOnNotificationKey: @YES}];
        [central stopScan];
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"Connect peripheral: %@, %@", peripheral.name, [peripheral.identifier UUIDString]);
    
    [peripheral discoverServices:nil];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Fail to connect peripheral: %@, %@", [peripheral.identifier UUIDString], error);
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"BLE" message:@"Connection failed" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alert show];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Disconnect peripheral: %@, %@", peripheral.name, [peripheral.identifier UUIDString]);
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"BLE" message:@"Disconnect" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alert show];
    
    self.activePeripheral = nil;
    [central scanForPeripheralsWithServices:nil options:nil];
    [central retrievePeripheralsWithIdentifiers:@[peripheral.identifier]];
}

#pragma mark CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error) {
        NSLog(@"Service discovery was unsuccessful!");
        return;
    }
    
    NSLog(@"Services of peripheral with UUID : %@ found", [peripheral.identifier UUIDString]);
    
    for (CBService *service in peripheral.services) {
        NSLog(@"Discovered service %@", service);
        [peripheral discoverCharacteristics:nil forService:service];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if (error) {
        NSLog(@"Characteristic discorvery unsuccessful!");
        return;
    }
    
    for (CBCharacteristic *characteristic in service.characteristics) {
        NSLog(@"Discovered characteristic %@", characteristic);
        
        if ([[service.UUID UUIDString] isEqualToString:RBL_SERVICE_UUID]) {
            [self sendInit];
            break;
        }
    }
}


- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        NSLog(@"Characteristic update unsuccessful!");
        return;
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        NSLog(@"Error changing notification state: %@", [error localizedDescription]);
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        NSLog(@"Error writing characteristic value: %@", [error localizedDescription]);
    }
}

#pragma mark custom core bluetooth methods

- (CBCharacteristic *)findCharacteristicOfLedEffect
{
    CBService *service = [self findServiceOfLedEffect];
    
    if (!service) {
        NSLog(@"Find service unsuccessful!");
        return nil;
    }
    
    for (CBCharacteristic *characteristic in service.characteristics) {
        if ([[characteristic.UUID UUIDString] isEqualToString:RBL_CHAR_RX_UUID]) {
            return characteristic;
        }
    }
    
    return nil;
}

- (CBService *)findServiceOfLedEffect
{
    for (CBService *service in self.activePeripheral.services) {
        if ([[service.UUID UUIDString] isEqualToString:RBL_SERVICE_UUID]) {
            return service;
        }
    }
    
    return nil;
}

#pragma mark send effect by BLE

- (void)sendInit
{
    UInt8 buf[] = {kInit};
    NSData *data = [NSData dataWithBytes:buf length:1];
    
    [self sendLedDataByBLE:data];
}

- (void)sendSingleLedColorByBLE:(int)led red:(int)red green:(int)green blue:(int)blue
{
    UInt8 buf[] = {kChangeSingleLedColor, 0x00, 0x00, 0x00, 0x00};
    buf[1] = led;
    buf[2] = red;
    buf[3] = green;
    buf[4] = blue;
    
    NSData *data = [NSData dataWithBytes:buf length:5];
    
    [self sendLedDataByBLE:data];
}

- (void)sendLedDataByBLE:(NSData *)data
{
    CBCharacteristic *characteristic = [self findCharacteristicOfLedEffect];
    
    if (!characteristic) {
        NSLog(@"Find characteristic unsuccessful!");
        return;
    }

    [self.activePeripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithoutResponse];
}

@end
