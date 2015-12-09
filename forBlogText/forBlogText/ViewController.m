//
//  ViewController.m
//  forBlogText
//
//  Created by Lucidy on 15/12/9.
//  Copyright © 2015年 Lucidy. All rights reserved.
//

#import "ViewController.h"
#import <iflyMSC/iflyMSC.h>
// 这个头文件是做什么的呢?
#import "ISRDataHelper.h"
// 还有这个
#import "IATConfig.h"

#import "PcmPlayerDelegate.h"
#import "PcmPlayer.h"
#import "TTSConfig.h"

typedef NS_OPTIONS(NSInteger, SynthesizeType) {
    NomalType           = 5,//普通合成
    UriType             = 6, //uri合成
};

@interface ViewController ()<IFlyRecognizerViewDelegate, IFlySpeechRecognizerDelegate, IFlySpeechRecognizerDelegate>
// 翻译好的Text会展示在这个label上.
@property (weak, nonatomic) IBOutlet UILabel *textView;
// 朗读这里的内容.
@property (weak, nonatomic) IBOutlet UITextField *VoiceText;

/*!
 *  语音识别控件
 *    录音时触摸控件结束录音，开始识别（相当于旧版的停止）；触摸其他位置，取消录音，结束会话（取消）
 *  出错时触摸控件，重新开启会话（相当于旧版的再说一次）；触摸其他位置，取消录音，结束会话（取消）
 *
 */
@property (nonatomic,strong)IFlyRecognizerView * iflyRecognizerView;

/*!
 *  语音识别类
 *   此类现在设计为单例，你在使用中只需要创建此对象，不能调用release/dealloc函数去释放此对象。所有关于语音识别的操作都在此类中。
 */
@property (nonatomic, strong)IFlySpeechRecognizer * iFlySpeechRecognizer;


@property (nonatomic, strong) IFlySpeechSynthesizer * iFlySpeechSynthesizer;//语音合成对象
@property (nonatomic, strong) PcmPlayer *audioPlayer;//用于播放音频的
@property (nonatomic, assign) SynthesizeType synType;//是何种合成方式
@property (nonatomic, assign) BOOL hasError;//将解析过程中是否出现错误
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 语音识别视图空间及配置.
    [self initRecognizerView];
    
    // 语音识别类的初始化及配置.
    [self initSpeechRecognizer];
 
    // 初始化语音合成
    [self initMakeVoice];
}
// !!!:语音识别视图空间及配置--方法.
-(void)initRecognizerView{
    _iflyRecognizerView = [[IFlyRecognizerView alloc] initWithCenter:self.view.center];
    _iflyRecognizerView.delegate = self;
    [_iflyRecognizerView setParameter: @"iat" forKey: [IFlySpeechConstant IFLY_DOMAIN]];
    //asr_audio_path保存录音文件名，如不再需要，设置value为nil表示取消，默认目录是documents
    [_iflyRecognizerView setParameter:@"asrview.pcm " forKey:[IFlySpeechConstant ASR_AUDIO_PATH]];
}
// !!!:语音识别类的初始化及配置--方法.
-(void)initSpeechRecognizer{
    //单例模式，无UI的实例
    if (_iFlySpeechRecognizer == nil) {
        _iFlySpeechRecognizer = [IFlySpeechRecognizer sharedInstance];
        
        [_iFlySpeechRecognizer setParameter:@"" forKey:[IFlySpeechConstant PARAMS]];
        
        //设置听写模式
        [_iFlySpeechRecognizer setParameter:@"iat" forKey:[IFlySpeechConstant IFLY_DOMAIN]];
    }
    _iFlySpeechRecognizer.delegate = self;
    
    if (_iFlySpeechRecognizer != nil) {
        IATConfig *instance = [IATConfig sharedInstance];
        
        //设置最长录音时间
        [_iFlySpeechRecognizer setParameter:instance.speechTimeout forKey:[IFlySpeechConstant SPEECH_TIMEOUT]];
        //设置后端点
        [_iFlySpeechRecognizer setParameter:instance.vadEos forKey:[IFlySpeechConstant VAD_EOS]];
        //设置前端点
        [_iFlySpeechRecognizer setParameter:instance.vadBos forKey:[IFlySpeechConstant VAD_BOS]];
        //网络等待时间
        [_iFlySpeechRecognizer setParameter:@"20000" forKey:[IFlySpeechConstant NET_TIMEOUT]];
        
        //设置采样率，推荐使用16K
        [_iFlySpeechRecognizer setParameter:instance.sampleRate forKey:[IFlySpeechConstant SAMPLE_RATE]];
        
        if ([instance.language isEqualToString:[IATConfig chinese]]) {
            //设置语言
            [_iFlySpeechRecognizer setParameter:instance.language forKey:[IFlySpeechConstant LANGUAGE]];
            //设置方言
            [_iFlySpeechRecognizer setParameter:instance.accent forKey:[IFlySpeechConstant ACCENT]];
        }else if ([instance.language isEqualToString:[IATConfig english]]) {
            [_iFlySpeechRecognizer setParameter:instance.language forKey:[IFlySpeechConstant LANGUAGE]];
        }
        //设置是否返回标点符号
        [_iFlySpeechRecognizer setParameter:instance.dot forKey:[IFlySpeechConstant ASR_PTT]];
    }
}

// !!!:语音合成的初始化
-(void)initMakeVoice{
    TTSConfig *instance = [TTSConfig sharedInstance];
    if (instance == nil) {
        return;
    }
    
    //合成服务单例
    if (_iFlySpeechSynthesizer == nil) {
        _iFlySpeechSynthesizer = [IFlySpeechSynthesizer sharedInstance];
    }
    
    _iFlySpeechSynthesizer.delegate = self;
    
    //设置语速1-100
    [_iFlySpeechSynthesizer setParameter:instance.speed forKey:[IFlySpeechConstant SPEED]];
    
    //设置音量1-100
    [_iFlySpeechSynthesizer setParameter:instance.volume forKey:[IFlySpeechConstant VOLUME]];
    
    //设置音调1-100
    [_iFlySpeechSynthesizer setParameter:instance.pitch forKey:[IFlySpeechConstant PITCH]];
    
    //设置采样率
    [_iFlySpeechSynthesizer setParameter:instance.sampleRate forKey:[IFlySpeechConstant SAMPLE_RATE]];
    
    //设置发音人
    [_iFlySpeechSynthesizer setParameter:instance.vcnName forKey:[IFlySpeechConstant VOICE_NAME]];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// !!!: push界面的识别,点击事件
- (IBAction)voiceToText:(id)sender {
    [self.iflyRecognizerView start];
}
// !!!: 触发语音识别类的点击事件
- (IBAction)voiceToTextWithoutUI:(id)sender {
    self.textView.text = @"";
    [_iFlySpeechRecognizer cancel];
    
    //设置音频来源为麦克风
    [_iFlySpeechRecognizer setParameter:IFLY_AUDIO_SOURCE_MIC forKey:@"audio_source"];
    
    //设置听写结果格式为json
    [_iFlySpeechRecognizer setParameter:@"json" forKey:[IFlySpeechConstant RESULT_TYPE]];
    
    //保存录音文件，保存在sdk工作路径中，如未设置工作路径，则默认保存在library/cache下
    [_iFlySpeechRecognizer setParameter:@"asr.pcm" forKey:[IFlySpeechConstant ASR_AUDIO_PATH]];
    
    [_iFlySpeechRecognizer setDelegate:self];
    
    [_iFlySpeechRecognizer startListening];
}
- (IBAction)speechAction:(id)sender {
    if ([self.VoiceText.text isEqualToString:@""]) {
        return;
    }
    
    if (_audioPlayer != nil && _audioPlayer.isPlaying == YES) {
        [_audioPlayer stop];
    }
    
    _synType = NomalType;
    
    self.hasError = NO;
    [NSThread sleepForTimeInterval:0.05];
    _iFlySpeechSynthesizer.delegate = self;
    [_iFlySpeechSynthesizer startSpeaking:self.VoiceText.text];
}

// !!!:实现代理方法
// !!!:注意有没有s, 语音识别的结果回调
-(void)onResult:(NSArray *)resultArray isLast:(BOOL)isLast
{
    NSMutableString *result = [[NSMutableString alloc] init];
    NSDictionary *dic = [resultArray objectAtIndex:0];
    for (NSString *key in dic) {
        [result appendFormat:@"%@",key];
    }
    
    // 注意: 语音识别回调返回结果是一个json格式字符串, 解析起来比较麻烦, 但是我们只需要其中的字符串部分, 这个过程讯飞也觉得麻烦, 就推出了一个工具类, 能将这个josn解析最终字符串返回. 这也是前面导入ISRDataHelper.h的作用.
    NSString * resu = [ISRDataHelper stringFromJson:result];
    self.textView.text = [NSString stringWithFormat:@"%@%@",self.textView.text,resu];
}
// !!!:解析失败代理方法
-(void)onError:(IFlySpeechError *)error
{
    NSLog(@"解析失败了");
}

// !!!:语音识别类的回调方法
//语音合成回调函数
- (void) onResults:(NSArray *) results isLast:(BOOL)isLast{
    NSMutableString *result = [[NSMutableString alloc] init];
    NSDictionary *dic = [results objectAtIndex:0];
    for (NSString *key in dic) {
        [result appendFormat:@"%@",key];
    }
    NSString * resu = [ISRDataHelper stringFromJson:result];
    self.textView.text = [NSString stringWithFormat:@"%@%@", self.textView.text, resu];
}

@end
