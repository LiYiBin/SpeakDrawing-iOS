//
//  MainViewController.m
//  SpeakDrawing
//
//  Created by YiBin on 2014/6/11.
//  Copyright (c) 2014年 YB. All rights reserved.
//

#import "MainViewController.h"

#import <OpenEars/LanguageModelGenerator.h>
#import <OpenEars/AcousticModel.h>
#import <OpenEars/PocketsphinxController.h>
#import <OpenEars/OpenEarsEventsObserver.h>

@interface MainViewController () <OpenEarsEventsObserverDelegate>

@property (strong, nonatomic) LanguageModelGenerator *languageModelGenerator;
@property (strong, nonatomic) PocketsphinxController *pocketspinxController;
@property (strong, nonatomic) OpenEarsEventsObserver *openEarsEventsObserver;

- (IBAction)touchDownMicrophone:(id)sender;
- (IBAction)touchUpMicrophone:(id)sender;

@end

@implementation MainViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // setup background
    self.view.backgroundColor = [[UIColor alloc] initWithPatternImage:[UIImage imageNamed:@"Background1"]];
    
    // testing OpenEars
    self.languageModelGenerator = [[LanguageModelGenerator alloc] init];
    
    NSArray *words = @[@"WORD", @"HELLO", @"GO"];
    NSString *name = @"name";
    NSString *modelPath = [AcousticModel pathToModel:@"AcousticModelEnglish"];
    
    NSError *error = [self.languageModelGenerator generateLanguageModelFromArray:words withFilesNamed:name forAcousticModelAtPath:modelPath];
    
    NSDictionary *languageGeneratorResults = nil;
    
    NSString *lmPath = nil;
    NSString *dicPath = nil;
    
    if ([error code] == noErr) {
        
        languageGeneratorResults = [error userInfo];
        
        lmPath = [languageGeneratorResults objectForKey:@"LMPath"];
        dicPath = [languageGeneratorResults objectForKey:@"DictionaryPath"];
        NSLog(@"Result: %@", languageGeneratorResults);
        
    } else {
        NSLog(@"Error: %@", [error localizedDescription]);
    }
    
    self.pocketspinxController = [[PocketsphinxController alloc] init];
    
//    self.pocketspinxController.verbosePocketSphinx = true; // for debug
    self.pocketspinxController.outputAudio = true;
    self.pocketspinxController.returnNbest = true;
    self.pocketspinxController.nBestNumber = 5;
    
    [self.pocketspinxController startListeningWithLanguageModelAtPath:lmPath dictionaryAtPath:dicPath acousticModelAtPath:modelPath languageModelIsJSGF:false];
    
    self.openEarsEventsObserver = [[OpenEarsEventsObserver alloc] init];
    self.openEarsEventsObserver.delegate = self;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Button's Action
- (IBAction)touchDownMicrophone:(id)sender
{
    
}

- (IBAction)touchUpMicrophone:(id)sender
{
    
}

#pragma mark - OpenEarsEventsObserverDelegate

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

@end
