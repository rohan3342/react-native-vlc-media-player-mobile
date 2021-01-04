#import "React/RCTConvert.h"
#import "RCTVLCPlayerMobile.h"
#import "React/RCTBridgeModule.h"
#import "React/RCTEventDispatcher.h"
#import "React/UIView+React.h"
#import <MobileVLCKit/MobileVLCKit.h>
#import <AVFoundation/AVFoundation.h>
static NSString *const statusKeyPath = @"status";
static NSString *const playbackLikelyToKeepUpKeyPath = @"playbackLikelyToKeepUp";
static NSString *const playbackBufferEmptyKeyPath = @"playbackBufferEmpty";
static NSString *const readyForDisplayKeyPath = @"readyForDisplay";
static NSString *const playbackRate = @"rate";

@implementation RCTVLCPlayerMobile
{
    
    /* Required to publish events */
    RCTEventDispatcher *_eventDispatcher;
    VLCMediaPlayer *_player;
    
    NSDictionary * _source;
    BOOL _paused;
    BOOL _started;
    
}

- (instancetype)initWithEventDispatcher:(RCTEventDispatcher *)eventDispatcher
{
    if ((self = [super init])) {
        _eventDispatcher = eventDispatcher;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillResignActive:)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillEnterForeground:)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
        
    }
    
    return self;
}

- (void)applicationWillResignActive:(NSNotification *)notification
{
    if (!_paused) {
        [self setPaused:_paused];
    }
}

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
    [self applyModifiers];
}

- (void)applyModifiers
{
    if(!_paused)
        [self play];
}

- (void)setPaused:(BOOL)paused
{
    if(_player){
        if(!paused){
            [self play];
        }else {
            [_player pause];
            _paused =  YES;
            _started = NO;
        }
    }
}

-(void)play
{
    if(_player){
        [_player play];
        _paused = NO;
        _started = YES;
    }
}

-(void)setResume:(BOOL)autoplay
{
    if(_player){
        [self _release];
    }
    // [bavv edit start]
    // NSArray *options = [NSArray arrayWithObject:@"--rtsp-tcp"];
    NSString* uri    = [_source objectForKey:@"uri"];
    NSURL* _uri    = [NSURL URLWithString:uri];
    
    // _player = [[VLCMediaPlayer alloc] initWithOptions:options];
    _player = [[VLCMediaPlayer alloc] init];
	// [bavv edit end]

    [_player setDrawable:self];
    _player.delegate = self;
    _player.scaleFactor = 0;
    //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mediaPlayerStateChanged:) name:VLCMediaPlayerStateChanged object:nil];
    //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mediaPlayerTimeChanged:) name:VLCMediaPlayerTimeChanged object:nil];
    NSMutableDictionary *mediaDictonary = [NSMutableDictionary new];
    //设置缓存多少毫秒
    // [mediaDictonary setObject:@"0" forKey:@"network-caching"];
    [mediaDictonary setObject:@"1" forKey:@"rtsp-tcp"];
    VLCMedia *media = [VLCMedia mediaWithURL:_uri];
    [media addOptions:mediaDictonary];
    _player.media = media;
    [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    NSLog(@"autoplay: %i",autoplay);
    self.onVideoLoadStart(@{
                            @"target": self.reactTag
                            });
}

-(void)setSource:(NSDictionary *)source
{
    if(_player){
        [self _release];
    }
    _source = source;
    // [bavv edit start]
    // NSArray *options = [NSArray arrayWithObject:@"--rtsp-tcp"];
    NSString* uri    = [source objectForKey:@"uri"];
    BOOL    autoplay = [RCTConvert BOOL:[source objectForKey:@"autoplay"]];
    NSURL* _uri    = [NSURL URLWithString:uri];
    
    //init player && play
    // _player = [[VLCMediaPlayer alloc] initWithOptions:options];
    _player = [[VLCMediaPlayer alloc] init];
    // [bavv edit end]

    [_player setDrawable:self];
    _player.delegate = self;
    _player.scaleFactor = 0;
    // [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mediaPlayerStateChanged:) name:VLCMediaPlayerStateChanged object:nil];
    // [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mediaPlayerTimeChanged:) name:VLCMediaPlayerTimeChanged object:nil];
    NSMutableDictionary *mediaDictonary = [NSMutableDictionary new];
    //设置缓存多少毫秒
    // [mediaDictonary setObject:@"0" forKey:@"network-caching"];
    [mediaDictonary setObject:@"1" forKey:@"rtsp-tcp"];
    VLCMedia *media = [VLCMedia mediaWithURL:_uri];
    [media addOptions:mediaDictonary];
    _player.media = media;
    [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    NSLog(@"autoplay: %i",autoplay);
    self.onVideoLoadStart(@{
                           @"target": self.reactTag
                           });
//    if(autoplay)
        [self play];
}

- (void)setFullScreen:(BOOL)isFullScreen
{
    if(isFullScreen) {
        UIScreen *screen = [UIScreen mainScreen];
        NSString *cropString = [NSString stringWithFormat: @"%i:%i", (int)screen.bounds.size.width, (int)screen.bounds.size.height];
        char *char_content = [cropString cStringUsingEncoding:NSASCIIStringEncoding];
        _player.videoCropGeometry = char_content;
    }
    else {
        _player.videoCropGeometry = NULL;
    }
     return;

 }

- (void)mediaPlayerTimeChanged:(NSNotification *)aNotification
{
    [self updateVideoProgress];
}

- (void)mediaPlayerStateChanged:(NSNotification *)aNotification
{
   
     NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
     NSLog(@"userInfo %@",[aNotification userInfo]);
     NSLog(@"standardUserDefaults %@",defaults);
    if(_player){
        VLCMediaPlayerState state = _player.state;
        switch (state) {
            case VLCMediaPlayerStateOpening:
                 NSLog(@"VLCMediaPlayerStateOpening %i",1);
                self.onVideoOpen(@{
                                     @"target": self.reactTag
                                     });
                break;
            case VLCMediaPlayerStatePaused:
                _paused = YES;
                NSLog(@"VLCMediaPlayerStatePaused %i",1);
                self.onVideoPaused(@{
                                     @"target": self.reactTag
                                     });
                break;
            case VLCMediaPlayerStateStopped:
                NSLog(@"VLCMediaPlayerStateStopped %i",1);
                self.onVideoStopped(@{
                                      @"target": self.reactTag
                                      });
                break;
            case VLCMediaPlayerStateBuffering:
                NSLog(@"VLCMediaPlayerStateBuffering %i",1);
                self.onVideoBuffering(@{
                                        @"target": self.reactTag
                                        });
                break;
            case VLCMediaPlayerStatePlaying:
                _paused = NO;
                NSLog(@"VLCMediaPlayerStatePlaying %i",1);
                self.onVideoPlaying(@{
                                      @"target": self.reactTag,
                                      @"seekable": [NSNumber numberWithBool:[_player isSeekable]],
                                      @"duration":[NSNumber numberWithInt:[_player.media.length intValue]]
                                      });
                break;
            case VLCMediaPlayerStateEnded:
                NSLog(@"VLCMediaPlayerStateEnded %i",1);
                int currentTime   = [[_player time] intValue];
                int remainingTime = [[_player remainingTime] intValue];
                int duration      = [_player.media.length intValue];
                
                self.onVideoEnded(@{
                                    @"target": self.reactTag,
                                    @"currentTime": [NSNumber numberWithInt:currentTime],
                                    @"remainingTime": [NSNumber numberWithInt:remainingTime],
                                    @"duration":[NSNumber numberWithInt:duration],
                                    @"position":[NSNumber numberWithFloat:_player.position]
                                    });
                break;
            case VLCMediaPlayerStateError:
                NSLog(@"VLCMediaPlayerStateError %i",1);
                self.onVideoError(@{
                                    @"target": self.reactTag
                                    });
                [self _release];
                break;
            default:
                break;
        }
    }
}

-(void)updateVideoProgress
{
    if(_player){
        int currentTime   = [[_player time] intValue];
        int remainingTime = [[_player remainingTime] intValue];
        int duration      = [_player.media.length intValue];

        NSObject *width = [NSNumber numberWithFloat:_player.videoSize.width];
        NSObject *height = [NSNumber numberWithFloat:_player.videoSize.height];
        
        if( currentTime >= 0 && self.onVideoProgress) {
            self.onVideoProgress(@{
                                   @"target": self.reactTag,
                                   @"currentTime": [NSNumber numberWithInt:currentTime],
                                   @"remainingTime": [NSNumber numberWithInt:remainingTime],
                                   @"duration":[NSNumber numberWithInt:duration],
                                   @"position":[NSNumber numberWithFloat:_player.position],
                                   @"textTracks": [self getTextTrackInfo],
                                   @"audioTracks": [self getAudioTrackInfo],
                                   @"naturalSize": @{
                                           @"width": width,
                                           @"height": height,
                                   }
                                   });
           }
        }
    }

//Method to get sub-titles
- (NSArray *)getTextTrackInfo
{
    // if streaming video, we extract the text tracks
    NSMutableArray *textTracks = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < _player.videoSubTitlesNames.count; ++i) {
        
        NSString *language = [_player.videoSubTitlesNames objectAtIndex:i];
        if (![[language lowercaseString] isEqualToString:@"disable"]) {
          // Do nothing. We want to ensure option is nil
            NSDictionary *textTrack = @{
                @"index": [NSNumber numberWithInt:i],
                @"title": language,
                @"language": language
            };
            [textTracks addObject:textTrack];
        }
    }
    return textTracks;
}

//Method to get audio tracks
- (NSArray *)getAudioTrackInfo
{
    NSMutableArray *audioTracks = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < _player.audioTrackNames.count; ++i) {
        
        NSString *language = [_player.audioTrackNames objectAtIndex:i];
        if (![[language lowercaseString] isEqualToString:@"disable"]) {
          // Do nothing. We want to ensure option is nil
            NSDictionary *audioTrack = @{
                @"index": [NSNumber numberWithInt:i],
                @"title": language,
                @"language": language
            };
            [audioTracks addObject:audioTrack];
        }
    }
    return audioTracks;
}

//Method to select sub-title from list
- (void)setSelectVideoSubtitleIndex:(NSInteger)index
{
    index += 1;
    if (index >= 0 && index < _player.videoSubTitlesIndexes.count) {
        _player.currentVideoSubTitleIndex = [_player.videoSubTitlesIndexes[index] intValue];
    }
}

//Method to select audio from list
- (void)setSelectAudioTrackIndex:(NSInteger)index
{
    index += 1;
    if (index >= 0 && index < _player.audioTrackIndexes.count) {
        //we can cast this cause we won't have more than 2 million audiotracks
        _player.currentAudioTrackIndex = [_player.audioTrackIndexes[index] intValue];
    }
}

- (void)jumpBackward:(int)interval
{
    if(interval>=0 && interval <= [_player.media.length intValue])
        [_player jumpBackward:interval];
}

- (void)jumpForward:(int)interval
{
    if(interval>=0 && interval <= [_player.media.length intValue])
        [_player jumpForward:interval];
}

-(void)setSeek:(float)pos
{
    if([_player isSeekable]){
        if(pos>=0 && pos <= 1){
            [_player setPosition:pos];
        }
    }
}

-(void)setSnapshotPath:(NSString*)path
{
    if(_player)
        [_player saveVideoSnapshotAt:path withWidth:0 andHeight:0];
}

-(void)setRate:(float)rate
{
    [_player setRate:rate];
}

-(void)setVideoAspectRatio:(NSString *)ratio{
    char *char_content = [ratio cStringUsingEncoding:NSASCIIStringEncoding];
    [_player setVideoAspectRatio:char_content];
}

- (void)_release
{
    if(_player){
        [_player pause];
        [_player stop];
        _player = nil;
        _eventDispatcher = nil;
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
}


#pragma mark - Lifecycle
- (void)removeFromSuperview
{
    NSLog(@"removeFromSuperview");
    [self _release];
    [super removeFromSuperview];
}

@end
