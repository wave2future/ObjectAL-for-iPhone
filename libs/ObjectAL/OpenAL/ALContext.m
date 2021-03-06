//
//  ALContext.m
//  ObjectAL
//
//  Created by Karl Stenerud on 10-01-09.
//
// Copyright 2009 Karl Stenerud
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// Note: You are NOT required to make the license available from within your
// iOS application. Including it in your project is sufficient.
//
// Attribution is not required, but appreciated :)
//

#import "ALContext.h"
#import "NSMutableArray+WeakReferences.h"
#import "ObjectALMacros.h"
#import "ALWrapper.h"
#import "OpenALManager.h"
#import "OALInterruptAPI.h"


ADD_INTERRUPT_API(ALSource);

@implementation ALContext

#pragma mark Object Management

+ (id) contextOnDevice:(ALDevice *) device attributes:(NSArray*) attributes
{
	return [[[self alloc] initOnDevice:device attributes:attributes] autorelease];
}

+ (id) contextOnDevice:(ALDevice*) device
	   outputFrequency:(int) outputFrequency
	  refreshIntervals:(int) refreshIntervals 
	synchronousContext:(bool) synchronousContext
		   monoSources:(int) monoSources
		 stereoSources:(int) stereoSources
{
	NSMutableArray* attributes = [NSMutableArray arrayWithCapacity:5];
	if(outputFrequency > 0)
	{
		[attributes addObject:[NSNumber numberWithInt:ALC_FREQUENCY]];
		[attributes addObject:[NSNumber numberWithInt:outputFrequency]];
	}
	if(refreshIntervals > 0)
	{
		[attributes addObject:[NSNumber numberWithInt:ALC_REFRESH]];
		[attributes addObject:[NSNumber numberWithInt:refreshIntervals]];
	}
	[attributes addObject:[NSNumber numberWithInt:ALC_SYNC]];
	[attributes addObject:[NSNumber numberWithInt:synchronousContext ? AL_TRUE : AL_FALSE]];
	
	if(monoSources >= 0)
	{
		[attributes addObject:[NSNumber numberWithInt:ALC_MONO_SOURCES]];
		[attributes addObject:[NSNumber numberWithInt:monoSources]];
	}
	if(stereoSources >= 0)
	{
		[attributes addObject:[NSNumber numberWithInt:ALC_STEREO_SOURCES]];
		[attributes addObject:[NSNumber numberWithInt:stereoSources]];
	}
	
	return [self contextOnDevice:device attributes:attributes];
}

- (id) initOnDevice:(ALDevice*) deviceIn
	outputFrequency:(int) outputFrequency
   refreshIntervals:(int) refreshIntervals 
 synchronousContext:(bool) synchronousContext
		monoSources:(int) monoSources
	  stereoSources:(int) stereoSources
{
	NSMutableArray* attributesList = [NSMutableArray arrayWithCapacity:5];
	if(outputFrequency > 0)
	{
		[attributesList addObject:[NSNumber numberWithInt:ALC_FREQUENCY]];
		[attributesList addObject:[NSNumber numberWithInt:outputFrequency]];
	}
	if(refreshIntervals > 0)
	{
		[attributesList addObject:[NSNumber numberWithInt:ALC_REFRESH]];
		[attributesList addObject:[NSNumber numberWithInt:refreshIntervals]];
	}
	[attributesList addObject:[NSNumber numberWithInt:ALC_SYNC]];
	[attributesList addObject:[NSNumber numberWithInt:synchronousContext ? AL_TRUE : AL_FALSE]];
	
	if(monoSources >= 0)
	{
		[attributesList addObject:[NSNumber numberWithInt:ALC_MONO_SOURCES]];
		[attributesList addObject:[NSNumber numberWithInt:monoSources]];
	}
	if(stereoSources >= 0)
	{
		[attributesList addObject:[NSNumber numberWithInt:ALC_STEREO_SOURCES]];
		[attributesList addObject:[NSNumber numberWithInt:stereoSources]];
	}
	
	return [self initOnDevice:deviceIn attributes:attributes];
}

- (id) initOnDevice:(ALDevice *) deviceIn attributes:(NSArray*) attributesIn
{
	if(nil != (self = [super init]))
	{
		OAL_LOG_DEBUG(@"%@: Init on %@ with attributes 0x%08x", self, deviceIn, attributesIn);
		// Build up an ALCint array for OpenAL's createContext function.
		ALCint* attributesList = nil;

		if([attributesIn count] > 0)
		{
			attributesList = (ALCint*)malloc(sizeof(ALCint) * [attributesIn count]);
			ALCint* attributePtr = attributesList;
			for(NSNumber* number in attributesIn)
			{
				*attributePtr++ = [number intValue];
			}
		}
		
		// Notify the device that we are being created.
		device = [deviceIn retain];
		[device notifyContextInitializing:self];

		// Open the context with our list of attributes.
		context = [ALWrapper createContext:device.device attributes:attributesList];
		
		listener = [[ALListener listenerForContext:self] retain];
		
		sources = [[NSMutableArray mutableArrayUsingWeakReferencesWithCapacity:32] retain];
		
		// Cache all attributes for this context.
		attributes = [[NSMutableArray arrayWithCapacity:5] retain];
		int buffSize = [ALWrapper getInteger:device.device attribute:ALC_ATTRIBUTES_SIZE];
		if(buffSize > 0)
		{
			if(nil != attributesList)
			{
				free(attributesList);
			}
			attributesList = malloc(sizeof(ALCint) * buffSize);
			if([ALWrapper getIntegerv:device.device attribute:ALC_ALL_ATTRIBUTES size:buffSize data:attributesList])
			{
				for(int i = 0; i < buffSize; i++)
				{
					[attributes addObject:[NSNumber numberWithInt:attributesList[i]]];
				}
			}
		}

		if(nil != attributesList)
		{
			free(attributesList);
		}
		
		suspendLock = [[SuspendLock lockWithTarget:self
									  lockSelector:@selector(onSuspend)
									unlockSelector:@selector(onUnsuspend)] retain];
	}
	return self;
}

- (void) dealloc
{
	OAL_LOG_DEBUG(@"%@: Dealloc", self);
	if([OpenALManager sharedInstance].currentContext == self)
	{
		[OpenALManager sharedInstance].currentContext = nil;
	}
	[device notifyContextDeallocating:self];
	[sources release];
	[listener release];
	[ALWrapper destroyContext:context];
	[device release];
	[attributes release];
	[suspendLock release];

	[super dealloc];
}


#pragma mark Properties

- (NSString*) alVersion
{
	return [ALWrapper getString:AL_VERSION];
}

@synthesize attributes;

@synthesize context;

@synthesize device;

- (ALenum) distanceModel
{
	OPTIONALLY_SYNCHRONIZED(self)
	{
		return [ALWrapper getInteger:AL_DISTANCE_MODEL];
	}
}

- (void) setDistanceModel:(ALenum) value
{
	OPTIONALLY_SYNCHRONIZED(self)
	{
		if(suspendLock.locked)
		{
			OAL_LOG_DEBUG(@"%@: Called mutator on suspended object", self);
			return;
		}
		
		[ALWrapper distanceModel:value];
	}
}

- (float) dopplerFactor
{
	OPTIONALLY_SYNCHRONIZED(self)
	{
		return [ALWrapper getFloat:AL_DOPPLER_FACTOR];
	}
}

- (void) setDopplerFactor:(float) value
{
	OPTIONALLY_SYNCHRONIZED(self)
	{
		if(suspendLock.locked)
		{
			OAL_LOG_DEBUG(@"%@: Called mutator on suspended object", self);
			return;
		}
		
		[ALWrapper dopplerFactor:value];
	}
}

- (NSArray*) extensions
{
	return [ALWrapper getSpaceSeparatedStringList:AL_EXTENSIONS];
}

@synthesize listener;

- (NSString*) renderer
{
	return [ALWrapper getString:AL_RENDERER];
}

@synthesize sources;

- (float) speedOfSound
{
	OPTIONALLY_SYNCHRONIZED(self)
	{
		return [ALWrapper getFloat:AL_SPEED_OF_SOUND];
	}
}

- (void) setSpeedOfSound:(float) value
{
	OPTIONALLY_SYNCHRONIZED(self)
	{
		if(suspendLock.locked)
		{
			OAL_LOG_DEBUG(@"%@: Called mutator on suspended object", self);
			return;
		}
		
		[ALWrapper speedOfSound:value];
	}
}

/** Called by SuspendLock to suspend this object.
 */
- (void) onSuspend
{
	[ALWrapper suspendContext:context];
}

/** Called by SuspendLock to unsuspend this object.
 */
- (void) onUnsuspend
{
	[self process];
}


- (bool) suspended
{
	// No need to synchronize since SuspendLock does that already.
	return suspendLock.suspendLock;
}

- (void) setSuspended:(bool) value
{
	// Ensure setting/resetting occurs in opposing order
	if(value)
	{
		for(ALSource* source in sources)
		{
			source.suspended = value;
		}
	}

	// No need to synchronize since SuspendLock does that already.
	suspendLock.suspendLock = value;

	// Ensure setting/resetting occurs in opposing order
	if(!value)
	{
		for(ALSource* source in sources)
		{
			source.suspended = value;
		}
	}
}

- (bool) interrupted
{
	// No need to synchronize since SuspendLock does that already.
	return suspendLock.interruptLock;
}

- (void) setInterrupted:(bool) value
{
	if(value)
	{
		for(ALSource* source in sources)
		{
			source.interrupted = value;
		}
	}

	// No need to synchronize since SuspendLock does that already.
	suspendLock.interruptLock = value;

	if(!value)
	{
		for(ALSource* source in sources)
		{
			source.interrupted = value;
		}
	}
}


- (NSString*) vendor
{
	return [ALWrapper getString:AL_VENDOR];
}


#pragma mark Utility

- (void) clearBuffers
{
	OPTIONALLY_SYNCHRONIZED(self)
	{
		for(ALSource* source in sources)
		{
			[source clear];
		}
	}
}

- (void) process
{
	if(suspendLock.locked)
	{
		OAL_LOG_DEBUG(@"%@: Called mutator on suspended object", self);
		return;
	}
	
	[ALWrapper processContext:context];
}

- (void) stopAllSounds
{
	OPTIONALLY_SYNCHRONIZED(self)
	{
		if(suspendLock.locked)
		{
			OAL_LOG_DEBUG(@"%@: Called mutator on suspended object", self);
			return;
		}
		
		for(ALSource* source in sources)
		{
			[source stop];
		}
	}
}

- (void) ensureContextIsCurrent
{
	if(suspendLock.locked)
	{
		OAL_LOG_DEBUG(@"%@: Called mutator on suspended object", self);
		return;
	}
	
	if([ALWrapper getCurrentContext] != context)
	{
		[OpenALManager sharedInstance].currentContext = self;
	}
}

#pragma mark Extensions

- (bool) isExtensionPresent:(NSString*) name
{
	return [ALWrapper isExtensionPresent:name];
}

- (void*) getProcAddress:(NSString*) functionName
{
	return [ALWrapper getProcAddress:functionName];
}


#pragma mark Internal Use

- (void) notifySourceInitializing:(ALSource*) source
{
	OPTIONALLY_SYNCHRONIZED(self)
	{
		[sources addObject:source];
	}
}

- (void) notifySourceDeallocating:(ALSource*) source
{
	OPTIONALLY_SYNCHRONIZED(self)
	{
		[sources removeObject:source];
	}
}


@end
