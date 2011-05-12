//
//  HelloWorldLayer.m
//  miniGame
//
//  Created by Sam Quinan on 5/12/11.
//  Copyright University of Chicago 2011. All rights reserved.
//


// Import the interfaces
#import "HelloWorldLayer.h"
#import "CCTouchDispatcher.h"

#define TOUCH_THRESHOLD 20

// HelloWorldLayer implementation
@implementation HelloWorldLayer
@synthesize sprites, spriteSheet;

+(CCScene *) scene
{
	// 'scene' is an autorelease object.
	CCScene *scene = [CCScene node];
	
	// 'layer' is an autorelease object.
	HelloWorldLayer *layer = [HelloWorldLayer node];
	
	// add layer as a child to scene
	[scene addChild: layer];
	
	// return the scene
	return scene;
}

-(void)setupSprites
{
    sprites = [NSMutableSet new];
    
    //init spriteSheet
    [[CCSpriteFrameCache sharedSpriteFrameCache] addSpriteFramesWithFile:@"spriteSheet.plist"];
    spriteSheet = [CCSpriteBatchNode batchNodeWithFile:@"spriteSheet.png"];
    [self addChild:spriteSheet];
    
    //initialize sprites
    CCSprite *cell1 = [CCSprite spriteWithSpriteFrameName:@"YellowBubble.png"];
    cell1.position = ccp( 50, 100 );
    [sprites addObject: cell1];
    [spriteSheet addChild: cell1];
    
    CCSprite *cell2 = [CCSprite spriteWithSpriteFrameName:@"YellowBubble.png"];
    cell2.position = ccp( 200, 300 );
    [sprites addObject: cell2];
    [spriteSheet addChild: cell2];
    
    CCSprite *cell3 = [CCSprite spriteWithSpriteFrameName:@"YellowBubble.png"];
    cell3.position = ccp( 150, 235 );
    [sprites addObject: cell3];
    [spriteSheet addChild: cell3];
    
}

// on "init" you need to initialize your instance
-(id) init
{
	// always call "super" init
	// Apple recommends to re-assign "self" with the "super" return value
	if( (self=[super init])) {
		
        [self setupSprites];
        
        // schedule a repeating callback on every frame
        [self schedule:@selector(nextFrame:)];
        
        //enable touch
        self.isTouchEnabled = YES;
	}
	return self;
}

-(void) registerWithTouchDispatcher
{
	[[CCTouchDispatcher sharedDispatcher] addTargetedDelegate:self priority:0 swallowsTouches:YES];
}

- (void) nextFrame:(ccTime)dt {
    //cell animations
}

- (BOOL)ccTouchBegan:(UITouch *)touch withEvent:(UIEvent *)event {
    return YES;
}

- (void)ccTouchEnded:(UITouch *)touch withEvent:(UIEvent *)event {
	CGPoint location = [self convertTouchToNodeSpace: touch];
    switch (touch.tapCount){
        case 2:
            //double tap behavior
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(singleTap)  object:nil];
            [self performSelector:@selector(doubleTap)];
            break;
        case 1:
        default:
            //one tap behavior
            singleTapLocation = location;
            [self performSelector:@selector(singleTap) withObject:nil afterDelay:.1];
    }
    
    
}

-(void)singleTap
{
    for (id object in sprites) {
        CCSprite *current = object;
        if ( (abs(current.position.x - singleTapLocation.x) < TOUCH_THRESHOLD) && (abs(current.position.y - singleTapLocation.y) < TOUCH_THRESHOLD)){
            [current setDisplayFrame:[[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:@"RedBubble.png"]];
            break;
        }
    }
}

-(void)doubleTap
{
    for (id object in sprites) {
        CCSprite *current = object;
        if ( (abs(current.position.x - singleTapLocation.x) < TOUCH_THRESHOLD) && (abs(current.position.y - singleTapLocation.y) < TOUCH_THRESHOLD)){
            [current setDisplayFrame:[[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:@"GreenBubble.png"]];
            break;
        }
    }
}


// on "dealloc" you need to release all your retained objects
- (void) dealloc
{
	// cocos2d will automatically release all the children (Label)
	[sprites release];
    [spriteSheet release];
	// don't forget to call "super dealloc"
	[super dealloc];
}
@end
