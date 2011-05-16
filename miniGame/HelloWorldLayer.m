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
#define CELL_RADIUS 21
#define V 0.2/100

// HelloWorldLayer implementation
@implementation HelloWorldLayer
@synthesize sprites, spriteSheet, CD8;

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
    
    //initialize regular cells
    CCSprite *cell1 = [CCSprite spriteWithSpriteFrameName:@"TCR_YCell.png"];
    cell1.position = ccp( 100, 100 );
    [sprites addObject: cell1];
    [spriteSheet addChild: cell1];
    
    CCSprite *cell2 = [CCSprite spriteWithSpriteFrameName:@"TCR_YCell.png"];
    cell2.position = ccp( 146, 111 );
    [sprites addObject: cell2];
    [spriteSheet addChild: cell2];
    
    CCSprite *cell3 = [CCSprite spriteWithSpriteFrameName:@"TCR_YCell.png"];
    cell3.position = ccp( 133, 65 );
    [sprites addObject: cell3];
    [spriteSheet addChild: cell3];
    
    CCSprite *cell4 = [CCSprite spriteWithSpriteFrameName:@"TCR_YCell.png"];
    cell4.position = ccp( 64, 132 );
    [sprites addObject: cell4];
    [spriteSheet addChild: cell4];
    
    CCSprite *cell5 = [CCSprite spriteWithSpriteFrameName:@"TCR_YCell.png"];
    cell5.position = ccp( 67, 65 );
    [sprites addObject: cell5];
    [spriteSheet addChild: cell5];
    
    CCSprite *cell6 = [CCSprite spriteWithSpriteFrameName:@"TCR_YCell.png"];
    cell6.position = ccp( 113, 146 );
    [sprites addObject: cell6];
    [spriteSheet addChild: cell6];
    
    CCSprite *cell7 = [CCSprite spriteWithSpriteFrameName:@"TCR_YCell.png"];
    cell7.position = ccp( 32, 97 );
    [sprites addObject: cell7];
    [spriteSheet addChild: cell7];
    
    //init main char
    CD8 = [CCSprite spriteWithSpriteFrameName:@"TCR_GCell.png"];
    CD8.position = ccp( 250, 100 );
    [spriteSheet addChild: CD8];

    
}

// on "init" you need to initialize your instance
-(id) init
{
	// always call "super" init
	// Apple recommends to re-assign "self" with the "super" return value
	if( (self=[super initWithColor:ccc4(189, 227, 219, 255)])) {
		
        [self setupSprites];
        chemokinesReleased = NO;
        
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
    [CD8 stopAllActions];
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
            [self performSelector:@selector(singleTap) withObject:nil afterDelay:.15];
    }
    
    
}

-(void)singleTap
{
    
    BOOL objectFound = NO;
    for (id object in sprites) {
        CCSprite *current = object;
        if ( (abs(current.position.x - singleTapLocation.x) < TOUCH_THRESHOLD) && (abs(current.position.y - singleTapLocation.y) < TOUCH_THRESHOLD)){
            objectFound = YES;
            //create normalized vector to find target location for CD8 
            double len = sqrt(((CD8.position.x - current.position.x) * (CD8.position.x - current.position.x)) + ((CD8.position.y - current.position.y) * (CD8.position.y - current.position.y)));
            float time = len * V;
            if (len != 0){
                CGPoint target;
                target.x = current.position.x + (CD8.position.x - current.position.x)*2*CELL_RADIUS/len;
                target.y = current.position.y + (CD8.position.y - current.position.y)*2*CELL_RADIUS/len;
                CCSequence *strike = [CCSequence actions: 
                                        [CCMoveTo actionWithDuration:time position:target],
                                        [CCCallBlock actionWithBlock:^{
                                                [self performSelector:@selector(induceCellDeath:) withObject:current afterDelay:.1];
                                            }],
                                      nil];
                [CD8 runAction:strike];
                //[self performSelector:@selector(induceCellDeath:) withObject:current afterDelay:.1];
            }
            break;
        }
    }
    if (!objectFound){
        double len = sqrt(((CD8.position.x - singleTapLocation.x) * (CD8.position.x - singleTapLocation.x)) + ((CD8.position.y - singleTapLocation.y) * (CD8.position.y - singleTapLocation.y)));
        float time = len * V;
        [CD8 runAction:[CCMoveTo actionWithDuration:time position:singleTapLocation]];
    }
}

-(void)doubleTap
{
    if ((abs(chemokineReleaseCoords.x - singleTapLocation.x) < (TOUCH_THRESHOLD * 1.5)) && 
        (abs(chemokineReleaseCoords.y - singleTapLocation.y) < (TOUCH_THRESHOLD * 1.5))){
            [self performSelector:@selector(chemokineSignal) withObject:nil afterDelay:.1];
    }
}

-(void)induceCellDeath:(CCSprite *)cell
{
    
    //create blinking animation
    NSMutableArray *blinkAnimFrames = [NSMutableArray array];
    [blinkAnimFrames addObject: [[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:[NSString stringWithFormat:@"TCR_RCell.png"]]];
    [blinkAnimFrames addObject: [[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:[NSString stringWithFormat:@"TCR_YCell.png"]]];
    [blinkAnimFrames addObject: [[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:[NSString stringWithFormat:@"TCR_RCell.png"]]];
    [blinkAnimFrames addObject: [[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:[NSString stringWithFormat:@"TCR_YCell.png"]]];
    [blinkAnimFrames addObject: [[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:[NSString stringWithFormat:@"TCR_RCell.png"]]];
    [blinkAnimFrames addObject: [[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:[NSString stringWithFormat:@"TCR_YCell.png"]]];
    [blinkAnimFrames addObject: [[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:[NSString stringWithFormat:@"TCR_RCell.png"]]];
    CCAnimation *blinkAnimation = [CCAnimation animationWithFrames:blinkAnimFrames];
    CCAnimate *blink = [CCAnimate actionWithDuration:0.7f animation:blinkAnimation restoreOriginalFrame:NO];
    CCAction *fade = [CCFadeTo actionWithDuration:0.5f opacity:0];
    
    CCSequence *die = [CCSequence actions:
                                            blink,
                                            fade,
                                            [CCCallBlock actionWithBlock:^{ [spriteSheet removeChild:cell cleanup:YES];
                                                                            [sprites removeObject:cell]; 
                                                                           }],
                                            nil
                       ];
    
    //log location for chemokine release
    chemokineReleaseCoords = cell.position;
    chemokinesReleased = NO;
    
    //kill cell
    [cell runAction:die];
}

-(void)chemokineSignal
{
    if (!chemokinesReleased){
        CCSprite *cell = [CCSprite spriteWithSpriteFrameName:@"TCR_YCell.png"];
        cell.position = chemokineReleaseCoords;
        [sprites addObject:cell];
        [spriteSheet addChild:cell];
        chemokinesReleased = YES;
    }
}




// on "dealloc" you need to release all your retained objects
- (void) dealloc
{
	// cocos2d will automatically release all the children (Label)
	[sprites release];
    [spriteSheet release];
    [CD8 release];
	// don't forget to call "super dealloc"
	[super dealloc];
}
@end
