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

#define RBL_SERVICE_UUID @"713D0000-503E-4C75-BA94-3148F18D941E"
#define RBL_CHAR_TX_UUID @"713D0002-503E-4C75-BA94-3148F18D941E"
#define RBL_CHAR_RX_UUID @"713D0003-503E-4C75-BA94-3148F18D941E"
#define RBL_BLE_FRAMEWORK_VER 0x0200

typedef enum {
    EmotionTypeAllHappy,
    EmotionTypeAllAngry,
    EmotionTypeAllHelpless,
    EmotionTypeAllWorried,
    EmotionTypeAllNervous,
    EmotionTypeAllExcited,
    EmotionTypeAddHappy,
    EmotionTypeAddAngry,
    EmotionTypeAddHelpless,
    EmotionTypeAddWorried,
    EmotionTypeAddNervous,
    EmotionTypeAddExcited
    
} EmotionType;

#define kInit 0x00
#define kAllHappy 0x01
#define kAllAngry 0x02
#define kAllHelpless 0x03
#define kAllWorried 0x04
#define kAllNervous 0x05
#define kAllExcited 0x06

#define kAddHappy 0x11
#define kAddAngry 0x12
#define kAddHelpless 0x13
#define kAddWorried 0x14
#define kAddNervous 0x15
#define kAddExcited 0x16

@interface MainViewController () <OpenEarsEventsObserverDelegate, CBCentralManagerDelegate, CBPeripheralDelegate>

// for ui and action of button
@property (weak, nonatomic) IBOutlet UIButton *microPhoneButton;
- (IBAction)touchDownMicrophone:(id)sender;
- (IBAction)touchUpMicrophone:(id)sender;

@property (weak, nonatomic) IBOutlet UIButton *messageButton;
- (IBAction)dragMessage:(id)sender withEvent:(UIEvent *)event;
- (IBAction)touchUpMessage:(id)sender;

// for speech recognition
@property (strong, nonatomic) LanguageModelGenerator *languageModelGenerator;
@property (strong, nonatomic) PocketsphinxController *pocketspinxController;
@property (strong, nonatomic) OpenEarsEventsObserver *openEarsEventsObserver;

@property (strong, nonatomic) NSString *modelPath;
@property (strong, nonatomic) NSString *lmPath;
@property (strong, nonatomic) NSString *dicPath;

- (void)setupSpeechRecognition;

// for emotion recognition
@property (strong, nonatomic) NSArray *happyWords;
@property (strong, nonatomic) NSNumber *happyScore;
@property (strong, nonatomic) NSArray *angryWords;
@property (strong, nonatomic) NSNumber *angryScore;
@property (strong, nonatomic) NSArray *helplessWords;
@property (strong, nonatomic) NSNumber *helplessScore;
@property (strong, nonatomic) NSArray *worriedWords;
@property (strong, nonatomic) NSNumber *worriedScore;
@property (strong, nonatomic) NSArray *nervousWords;
@property (strong, nonatomic) NSNumber *nervousScore;
@property (strong, nonatomic) NSArray *excitedWords;
@property (strong, nonatomic) NSNumber *excitedScore;

// for bluetooth
@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) CBPeripheral *activePeripheral;

// for effect
- (void)sendDataByBLE:(NSData *)data;
- (void)sendInit;
- (void)sendEmotion:(EmotionType)type;

@end

@implementation MainViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // setup background
    self.view.backgroundColor = [[UIColor alloc] initWithPatternImage:[UIImage imageNamed:@"Background1"]];

    // setup bluetooth
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:@{CBConnectPeripheralOptionNotifyOnNotificationKey: @YES}];
    
    [self setupSpeechRecognition];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)initButtonsOfSpeech:(NSTimer *)timer
{
    self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"Background1"]];
    self.microPhoneButton.hidden = NO;
    self.messageButton.hidden = YES;
    self.messageButton.center = CGPointMake(232, 600);
}

#pragma mark - Speech Recognition

- (void)setupSpeechRecognition
{
    self.languageModelGenerator = [[LanguageModelGenerator alloc] init];
    
    NSArray *words = [self setupEmotionWords];
    NSString *name = @"EmotionGrammars";
    self.modelPath = [AcousticModel pathToModel:@"AcousticModelChinese"];
    
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

- (NSArray *)setupEmotionWords
{
    self.happyWords = @[@"開心"];
    self.angryWords = @[@"討厭", @"幹"];
    self.helplessWords = @[@"無奈", @"唉"];
    self.worriedWords = @[@"煩"];
    self.nervousWords = @[@"緊張"];
    self.excitedWords = @[@"高興", @"爽"];
    
    NSMutableArray *allWords = [[NSMutableArray alloc] init];
    [allWords addObjectsFromArray:self.happyWords];
    [allWords addObjectsFromArray:self.angryWords];
    [allWords addObjectsFromArray:self.helplessWords];
    [allWords addObjectsFromArray:self.worriedWords];
    [allWords addObjectsFromArray:self.nervousWords];
    [allWords addObjectsFromArray:self.excitedWords];
    
    return (NSArray *)allWords;
}

#pragma mark IBAction for Speech Recognition

- (IBAction)touchDownMicrophone:(id)sender
{
    self.happyScore = @(0);
    self.angryScore = @(0);
    self.helplessScore = @(0);
    self.worriedScore = @(0);
    self.nervousScore = @(0);
    self.excitedScore = @(0);
    
    [self.pocketspinxController startListeningWithLanguageModelAtPath:self.lmPath dictionaryAtPath:self.dicPath acousticModelAtPath:self.modelPath languageModelIsJSGF:false];
}

- (IBAction)touchUpMicrophone:(id)sender
{
    [self.pocketspinxController stopListening];
    
    if (self.happyScore.intValue > 0 || self.angryScore.intValue > 0 || self.helplessScore.intValue > 0 || self.worriedScore.intValue > 0 || self.nervousScore.intValue > 0 || self.excitedScore.intValue > 0) {
    
        self.microPhoneButton.hidden = YES;
        self.messageButton.hidden = NO;
        self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"Background2"]];
    }
}

- (IBAction)dragMessage:(id)sender withEvent:(UIEvent *)event
{
    UIButton *button = (UIButton *)sender;
    UITouch *touch = [[event touchesForView:button] anyObject];
    
    // get delta
    CGPoint previousLocation = [touch previousLocationInView:button];
    CGPoint location = [touch locationInView:button];
    CGFloat delta_x = location.x - previousLocation.x;
    CGFloat delta_y = location.y - previousLocation.y;
    
    // move button
    button.center = CGPointMake(button.center.x + delta_x,
                                button.center.y + delta_y);
}

- (IBAction)touchUpMessage:(id)sender
{
    // send emotion
    NSArray *list = @[self.happyScore, self.angryScore, self.helplessScore, self.worriedScore, self.nervousScore, self.excitedScore];
    NSArray *sorted = [list sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        if ([obj1 intValue] > [obj2 intValue]) {
            return NSOrderedDescending;
        } else if ([obj1 intValue] < [obj2 intValue]) {
            return NSOrderedAscending;
        } else {
            return NSOrderedSame;
        }
    }];
    
    // send emotion
    if (sorted[0] == self.happyScore) {
        [self sendEmotion:EmotionTypeAllHappy];
//        [self sendEmotion:EmotionTypeAddHappy];
    } else if (sorted[0] == self.angryScore) {
        [self sendEmotion:EmotionTypeAllAngry];
//        [self sendEmotion:EmotionTypeAddAngry];
    } else if (sorted[0] == self.helplessScore){
        [self sendEmotion:EmotionTypeAllHelpless];
//        [self sendEmotion:EmotionTypeAddHelpless];
    } else if (sorted[0] == self.worriedScore){
        [self sendEmotion:EmotionTypeAllWorried];
//        [self sendEmotion:EmotionTypeAddWorried];
    } else if (sorted[0] == self.nervousScore){
        [self sendEmotion:EmotionTypeAllNervous];
//        [self sendEmotion:EmotionTypeAddNervous];
    } else if (sorted[0] == self.excitedScore){
        [self sendEmotion:EmotionTypeAllExcited];
//        [self sendEmotion:EmotionTypeAddExcited];
    }
    
    // button animation
    UIButton *button = (UIButton *)sender;
    
    [UIView animateWithDuration:1.0 animations:^{
        button.center = CGPointMake(384, -500);
    } completion:^(BOOL finished) {
        [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(initButtonsOfSpeech:) userInfo:nil repeats:NO];
    }];
}

#pragma mark OpenEarsEventsObserverDelegate

- (void) pocketsphinxDidReceiveHypothesis:(NSString *)hypothesis recognitionScore:(NSString *)recognitionScore utteranceID:(NSString *)utteranceID {
	NSLog(@"The received hypothesis is %@ with a score of %@ and an ID of %@", hypothesis, recognitionScore, utteranceID);
    
    int value = 0;
    NSArray *words = [hypothesis componentsSeparatedByString:@" "];
    
    for (NSString *word in words) {
        if ([self.happyWords containsObject:word]) {
            value = [self.happyScore intValue];
            self.happyScore = @(++value);
        } else if ([self.angryWords containsObject:word]) {
            value = [self.angryScore intValue];
            self.angryScore = @(++value);
        } else if ([self.helplessWords containsObject:word]) {
            value = [self.helplessScore intValue];
            self.helplessScore = @(++value);
        } else if ([self.worriedWords containsObject:word]) {
            value = [self.worriedScore intValue];
            self.worriedScore = @(++value);
        } else if ([self.nervousWords containsObject:word]) {
            value = [self.nervousScore intValue];
            self.nervousScore = @(++value);
        } else if ([self.excitedWords containsObject:word]) {
            value = [self.excitedScore intValue];
            self.excitedScore = @(++value);
        }
    }
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
    
    [self sendDataByBLE:data];
}

- (void)sendEmotion:(EmotionType)type
{
    UInt8 buf[] = { 0x00 };
    
    switch (type) {
        case EmotionTypeAllHappy:
            buf[0] = kAllHappy;
            break;
        case EmotionTypeAllAngry:
            buf[0] = kAllAngry;
            break;
        case EmotionTypeAllHelpless:
            buf[0] = kAllHelpless;
            break;
        case EmotionTypeAllWorried:
            buf[0] = kAllWorried;
            break;
        case EmotionTypeAllNervous:
            buf[0] = kAllNervous;
            break;
        case EmotionTypeAllExcited:
            buf[0] = kAllExcited;
            break;
        case EmotionTypeAddHappy:
            buf[0] = kAddHappy;
            break;
        case EmotionTypeAddAngry:
            buf[0] = kAddAngry;
            break;
        case EmotionTypeAddHelpless:
            buf[0] = kAddHelpless;
            break;
        case EmotionTypeAddWorried:
            buf[0] = kAddWorried;
            break;
        case EmotionTypeAddNervous:
            buf[0] = kAddNervous;
            break;
        case EmotionTypeAddExcited:
            buf[0] = kAddExcited;
            break;
        default:
            NSLog(@"Unknown emotion type!");
            break;
    }
    
    NSData *data = [NSData dataWithBytes:buf length:1];
    
    [self sendDataByBLE:data];
}

- (void)sendDataByBLE:(NSData *)data
{
    CBCharacteristic *characteristic = [self findCharacteristicOfLedEffect];
    
    if (!characteristic) {
        NSLog(@"Find characteristic unsuccessful!");
        return;
    }

    [self.activePeripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithoutResponse];
}

@end
