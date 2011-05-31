//
//  HelloWorldLayer.m
//  miniGame
//
//  Created by Sam Quinan on 5/12/11.
//  Copyright University of Chicago 2011. All rights reserved.
//


// Import the interfaces
#import "TCCollisionLayer.h"
#import "CCTouchDispatcher.h"
#import "TCGame.h"
#import "TCCell.h"
#import "SimpleAudioEngine.h"

#define TOUCH_THRESHOLD 20
#define CELL_RADIUS 21
#define V 0.2/100
#define V2 5

#define OFFSET 25

#define ARC4RANDOM_MAX      0x100000000
static inline double randf(){
    return (double)arc4random() / ARC4RANDOM_MAX;
}

static inline double lerp(double a, double b, double t)
{
    return a + (b - a) * t;
}

// HelloWorldLayer implementation
@implementation TCCollisionLayer
@synthesize sprites, objects, spriteSheet, CD8;

+(CCScene *) scene
{
	// 'scene' is an autorelease object.
	CCScene *scene = [CCScene node];
	
	// 'layer' is an autorelease object.
	TCCollisionLayer *layer = [TCCollisionLayer node];
	
	// add layer as a child to scene
	[scene addChild: layer];
	
	// return the scene
	return scene;
}

-(CGPoint) getVectorFromPoint:(CGPoint) cur ToPoint:(CGPoint) dst{
    CGPoint vec;
    double len = sqrt(((dst.x - cur.x) * (dst.x - cur.x)) + ((dst.y - cur.y) * (dst.y - cur.y)));
    vec.x = (dst.x - cur.x)/len;
    vec.y = (dst.y - cur.y)/len;
    return vec;
}

-(void)setupSprites
{
    self.sprites = [NSMutableArray new];
    self.objects = [NSMutableArray new];
    
    //init spriteSheet
    [[CCSpriteFrameCache sharedSpriteFrameCache] addSpriteFramesWithFile:@"spriteSheet.plist"];
    spriteSheet = [CCSpriteBatchNode batchNodeWithFile:@"spriteSheet.png"];
    [self addChild:spriteSheet];
    
    for (id obj in game.cells){
        TCCell *next = obj; 
        CCSprite *cellSprite = [CCSprite spriteWithSpriteFrameName:@"TCR_YCell.png"];
        cellSprite.position = next.bind_pos;
        [spriteSheet addChild: cellSprite];
        [sprites addObject:cellSprite];
        [objects addObject:next];
    }

    CGSize s = [[CCDirector sharedDirector] winSize];
    //init main char
    CD8 = [CCSprite spriteWithSpriteFrameName:@"TCR_GCell.png"];
    CD8.position = ccp( s.width/2, s.height/2 );
    [spriteSheet addChild: CD8];
    
}

// on "init" you need to initialize your instance
-(id) init
{
	// always call "super" init
	// Apple recommends to re-assign "self" with the "super" return value
	if( (self=[super initWithColor:ccc4(189, 227, 219, 255)])) {
		
        //initialize game model
        game = [[TCGame alloc] init];
        
        //sound setup
        [[SimpleAudioEngine sharedEngine] preloadEffect:@"Bing2.mp3"];
        [[SimpleAudioEngine sharedEngine] preloadEffect:@"Alert.wav"];
        
        [self setupSprites];
        chemokinesReleased = NO;
        
        //setup score labels
        CGSize s = [[CCDirector sharedDirector] winSize];
        totalLabel = [[CCLabelBMFont labelWithString:[NSString stringWithFormat:@"%i",game.num_remaining] fntFile:@"Times32.fnt"] retain];
        totalLabel.position = ccp((s.width - 32),(s.height - 32));
        totalLabel.color = ccBLACK;
        [self addChild:totalLabel];
        
        CCLabelBMFont *segment = [CCLabelBMFont labelWithString:@":" fntFile:@"Times32.fnt"];
        segment.position = ccp((s.width - 32*(2)),(s.height - 29));
        segment.color = ccBLACK;
        [self addChild:segment];
        
        infectedLabel = [[CCLabelBMFont labelWithString:[NSString stringWithFormat:@"%i",game.num_infected] fntFile:@"Times32.fnt"] retain];
        infectedLabel.position = ccp((s.width - 32*(3)),(s.height - 32));
        infectedLabel.color = ccRED;
        [self addChild:infectedLabel];
                
        // schedule a repeating callback on every frame
        [self schedule:@selector(nextFrame:)];
        
        //enable touch
        self.isTouchEnabled = YES;
        
        killed = 0;
        timeBegin = [[NSDate date] timeIntervalSince1970];
	}
	return self;
}

-(void) registerWithTouchDispatcher
{
	[[CCTouchDispatcher sharedDispatcher] addTargetedDelegate:self priority:0 swallowsTouches:YES];
}

-(void) checkWinLose
{
    if ((game.num_infected == game.num_remaining) || (game.num_infected == 0)){
        self.isTouchEnabled = NO;
        
        CGSize s = [[CCDirector sharedDirector] winSize];
        CGPoint center = ccp(s.width/2,s.height/2);
        
        int killScore = killed * 10;
        CCLabelBMFont *killScoreLabel = [CCLabelBMFont labelWithString:[NSString stringWithFormat:@"%i Killed x 10 = %i",killed, killScore] fntFile:@"Times32.fnt"];
        killScoreLabel.position = ccp(center.x, center.y + 40);
        killScoreLabel.color = ccBLACK;
        killScoreLabel.opacity = 0;
        [self addChild:killScoreLabel];
        [killScoreLabel runAction:[CCFadeTo actionWithDuration:0.5f opacity:255]];
        
        int numSaved = game.num_remaining;
        int savedScore = numSaved * 15;
        CCLabelBMFont *savedScoreLabel = [CCLabelBMFont labelWithString:[NSString stringWithFormat:@"%i Saved x 15 = %i", numSaved, savedScore] fntFile:@"Times32.fnt"];
        savedScoreLabel.position = center;
        savedScoreLabel.color = ccBLACK;
        savedScoreLabel.opacity = 0;
        [self addChild:savedScoreLabel];
        [savedScoreLabel runAction:[CCFadeTo actionWithDuration:0.5f opacity:255]];
         
        double timeElapsed = [[NSDate date] timeIntervalSince1970] - timeBegin;
        double timeBonus = MAX((60.0 - timeElapsed), 0.0);
        int timeScore = round(timeBonus * 5);
        CCLabelBMFont *timeScoreLabel = [CCLabelBMFont labelWithString:[NSString stringWithFormat:@"%.2f Time Bonus x 5 = %i", timeBonus, timeScore] fntFile:@"Times32.fnt"];
        timeScoreLabel.position = ccp(center.x, center.y - 40);
        timeScoreLabel.color = ccBLACK;
        timeScoreLabel.opacity = 0;
        [self addChild:timeScoreLabel];
        [timeScoreLabel runAction:[CCFadeTo actionWithDuration:0.5f opacity:255]];
        
        int totalScore = killScore + savedScore + timeScore;
        CCLabelBMFont *totalScoreLabel = [CCLabelBMFont labelWithString:[NSString stringWithFormat:@" TOTAL = %i", totalScore] fntFile:@"Times32.fnt"];
        totalScoreLabel.position = ccp(center.x, center.y - 80);
        totalScoreLabel.color = ccRED;
        totalScoreLabel.opacity = 0;
        [self addChild:totalScoreLabel];
        [totalScoreLabel runAction:[CCFadeTo actionWithDuration:0.5f opacity:255]];

    }
}

- (void) nextFrame:(ccTime)dt {
    //cell animations
    //FOR EACH CELL
    for (id obj in sprites){
        CCSprite *spriteCell = obj;
        TCCell *cellModel = [objects objectAtIndex:[sprites indexOfObject:spriteCell]];
        
        //get vector from current position to dst position
        CGPoint direction = [self getVectorFromPoint:spriteCell.position ToPoint:cellModel.dest_pos];
        
        //if not moving, get new dst
        if (CGPointEqualToPoint(cellModel.dest_pos, ccp(0,0)) || ccpFuzzyEqual(spriteCell.position, cellModel.dest_pos, 0.2)){
            [cellModel get_new_dest];
            direction = [self getVectorFromPoint:spriteCell.position ToPoint:cellModel.dest_pos];
        }
        
        //update current position
        spriteCell.position = ccp( spriteCell.position.x + direction.x*V2*dt, spriteCell.position.y + direction.y*V2*dt);
    }
    //END
    float delta = (float)dt;
    
    NSArray *updateList = game.cur_infected;
    for (id obj in updateList){
        TCCell *current = obj;
        current.replication_time -= delta;
        if (current.replication_time <= 0){
            [game spread_infection:current];
            [infectedLabel setString:[NSString stringWithFormat:@"%i", game.num_infected]];
            [self checkWinLose];
        }
    }
}

- (BOOL)ccTouchBegan:(UITouch *)touch withEvent:(UIEvent *)event {
    return YES;
}

- (void)ccTouchEnded:(UITouch *)touch withEvent:(UIEvent *)event {
    [CD8 stopAllActions];
	CGPoint location = [self convertTouchToNodeSpace: touch];
    switch (touch.tapCount){
        case 3:
            break;
        case 2:
            //double tap behavior
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(singleTap)  object:nil];
            [self performSelector:@selector(doubleTap)];
            break;
        case 1:
        default:
            //one tap behavior
            singleTapLocation = location;
            [self performSelector:@selector(singleTap) withObject:nil afterDelay:0.0];
    }
    
    
}

-(void)singleTap
{
    BOOL objectFound = NO;
    for (id object in sprites) {
        CCSprite *current = object;
        TCCell *model = [objects objectAtIndex:[sprites indexOfObject:object]];
        if ( (abs(current.position.x - singleTapLocation.x) < TOUCH_THRESHOLD) && (abs(current.position.y - singleTapLocation.y) < TOUCH_THRESHOLD)){
            objectFound = YES;
            //create normalized vector to find target location for CD8 
            double len = sqrt(((CD8.position.x - current.position.x) * (CD8.position.x - current.position.x)) + ((CD8.position.y - current.position.y) * (CD8.position.y - current.position.y)));
            float time = len * V;
            if (len != 0){
                float dx = (CD8.position.x - current.position.x)/len;
                float dy = (CD8.position.y - current.position.y)/len;
                CGPoint target;
                target.x = round(current.position.x + dx*1.75*CELL_RADIUS);
                target.y = round(current.position.y + dy*1.75*CELL_RADIUS);
                
                NSMutableArray *actions = [NSMutableArray new];
                [actions addObject:[CCMoveTo actionWithDuration:time position:target]];
                if (model.infected){
                    [actions addObject:[CCCallBlock actionWithBlock:^{
                        //increment user kill count
                        killed++;
                        //kill cell
                        [self performSelector:@selector(induceCellDeath:) withObject:current afterDelay:.1];
                    }]];
                }
                
                //target2 and time2 are location and duration for kiss-of-death pull back
                //CGPoint target2;
                //target2.x = round(current.position.x + 2*dx*CELL_RADIUS);
                //target2.y = round(current.position.y + 2*dy*CELL_RADIUS);
                //float time2 = sqrt(dx*dx + dy*dy) * V;
                //[actions addObject:[CCMoveTo actionWithDuration:time2 position:target2]];
                
                [CD8 runAction:[CCSequence actionsWithArray:actions]];
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
    if ([sprites containsObject:cell]){
        TCCell *model = [objects objectAtIndex:[sprites indexOfObject:cell]];
    
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
        CCSequence *die = [CCSequence actions:
                                                [CCCallBlock actionWithBlock:^{ [game kill_cell:model]; }],
                                                blink,
                                                [CCSpawn actions:   [CCScaleTo actionWithDuration:0.5f scale:0], 
                                                                    [CCFadeTo actionWithDuration:0.5f opacity:0],
                                                                    [CCCallBlock actionWithBlock:^{ [[SimpleAudioEngine sharedEngine] playEffect:@"Bing2.mp3"]; }], 
                                                                    nil],
                                                [CCCallBlock actionWithBlock:^{ [spriteSheet removeChild:cell cleanup:YES];
                                                                                [sprites removeObject:cell];
                                                                                [objects removeObject:model];
                                                                                //update to handle game state change
                                                                                [infectedLabel setString:[NSString stringWithFormat:@"%i", game.num_infected]];
                                                                                [totalLabel setString:[NSString stringWithFormat:@"%i", game.num_remaining]];
                                                                                [self checkWinLose];
                                                                            }],
                                                nil
                           ];
    
        //log location for chemokine release
        chemokineReleaseCoords = cell.position;
        chemokinesReleased = NO;
    
        //kill cell
        [cell runAction:die];
    }
}

-(void)chemokineSignal
{
    if (!chemokinesReleased){

        chemokinesReleased = YES;
        
        //generate helper t-cell coordinates
        CGPoint hLCoords;
        CGPoint hRCoords;
        
        CGSize s = [[CCDirector sharedDirector] winSize];
        if (chemokineReleaseCoords.x < s.width/2){
            hLCoords.x = -OFFSET;
            hRCoords.x = round(lerp(0.0, s.width/2, randf()));
        }
        else{
            hLCoords.x = s.width + OFFSET;
            hRCoords.x = round(lerp(s.width/2, s.width, randf()));
        }
        
        if (chemokineReleaseCoords.y < s.height/2){
            hLCoords.y = round(lerp(0.0, s.height/2, randf()));
            hRCoords.y = -OFFSET;
        }
        else{
            hLCoords.y = round(lerp(s.height/2, s.height, randf()));
            hRCoords.y = s.height + OFFSET;
        }
        
        //cell initialized offscreen
        CCSprite *hLCell = [CCSprite spriteWithSpriteFrameName:@"TCR_GCell.png"];
        hLCell.position = hLCoords;
        [spriteSheet addChild:hLCell];
        
        CCSprite *hRCell = [CCSprite spriteWithSpriteFrameName:@"TCR_GCell.png"];
        hRCell.position = hRCoords;
        [spriteSheet addChild:hRCell];
        
        //self.toBeKilled = [game cells_near_point:chemokineReleaseCoords];
        NSArray *tmp = [game cells_near_point:chemokineReleaseCoords];
        
        CGPoint current = hLCoords;
        
        float time;
        double len;
        
        // cell traverses cloud
        NSRange leftRange;
        leftRange.location = 0;
        leftRange.length = [tmp count]/2;
        NSArray *left = [tmp subarrayWithRange:leftRange];
        NSMutableArray *leftActions = [[NSMutableArray alloc] initWithCapacity:1];
        for (id obj in left){
            TCCell *model = obj;
            CCSprite *next = [sprites objectAtIndex:[objects indexOfObject:model]];
            //get target point and speed
            len = sqrt(((current.x - next.position.x) * (current.x - next.position.x)) + ((current.y - next.position.y) * (current.y - next.position.y)));
            time = len * V;
            CGPoint target;
            target.x = round(next.position.x + (current.x - next.position.x)*1*CELL_RADIUS/len);
            target.y = round(next.position.y + (current.y - next.position.y)*1*CELL_RADIUS/len);
            [leftActions addObject:[CCMoveTo actionWithDuration:time position:target]];
            if (model.infected){
                [leftActions addObject:[CCCallBlock actionWithBlock:^{
                                            [self performSelector:@selector(induceCellDeath:) withObject:next afterDelay:.1];
                                        }]];
            }
            [leftActions addObject:[CCDelayTime actionWithDuration:.4]];
            current = next.position;
        }
        // cell leaves screen 
        len = sqrt(((current.x - hRCoords.x) * (current.x - hRCoords.x)) + ((current.y - hRCoords.y) * (current.y - hRCoords.y)));
        time = len * V;
        [leftActions addObject:[CCMoveTo actionWithDuration:time position:hRCoords]];
        
        // cell traverses cloud
        current = hRCoords;
        NSRange rightRange;
        rightRange.location = [tmp count]/2;
        rightRange.length = [tmp count] - ([tmp count]/2);
        NSArray *right = [tmp subarrayWithRange:rightRange];
        NSMutableArray *rightActions = [[NSMutableArray alloc] initWithCapacity:1];
        for (id obj in right){
            TCCell *model = obj;
            CCSprite *next = [sprites objectAtIndex:[objects indexOfObject:model]];
            //get target point and speed
            len = sqrt(((current.x - next.position.x) * (current.x - next.position.x)) + ((current.y - next.position.y) * (current.y - next.position.y)));
            time = len * V;
            CGPoint target;
            target.x = round(next.position.x + (current.x - next.position.x)*1*CELL_RADIUS/len);
            target.y = round(next.position.y + (current.y - next.position.y)*1*CELL_RADIUS/len);
            [rightActions addObject:[CCMoveTo actionWithDuration:time position:target]];
            if (model.infected){
            [rightActions addObject:[CCCallBlock actionWithBlock:^{
                                        [self performSelector:@selector(induceCellDeath:) withObject:next afterDelay:.1];
                                    }]];
            }
            [rightActions addObject:[CCDelayTime actionWithDuration:.5]];
            current = next.position;
        }
        // cell leaves screen 
        len = sqrt(((current.x - hLCoords.x) * (current.x - hLCoords.x)) + ((current.y - hLCoords.y) * (current.y - hLCoords.y)));
        time = len * V;
        [rightActions addObject:[CCMoveTo actionWithDuration:time position:hLCoords]];
        
        
        [[SimpleAudioEngine sharedEngine] playEffect:@"Alert.wav"];
        [hLCell runAction:[CCSequence actionsWithArray:leftActions]];
        [hRCell runAction:[CCSequence actionsWithArray:rightActions]];
        [leftActions release];
        [rightActions release];
        
    }
}




// on "dealloc" you need to release all your retained objects
- (void) dealloc
{
	// cocos2d will automatically release all the children (Label)
	[sprites release];
    [objects release];
    [spriteSheet release];
    [CD8 release];
    [infectedLabel release];
    [totalLabel release];
    [game release];
	// don't forget to call "super dealloc"
	[super dealloc];
}
@end
