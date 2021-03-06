//
//  OALInterruptAPI.h
//  ObjectAL
//
//  Created by Karl Stenerud
//
// Copyright 2010 Karl Stenerud
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

/** Add a writable "interrupted" property to the specified class.
 */
#define ADD_INTERRUPT_API(CLASS) \
@class CLASS; \
@interface CLASS (OALWritableInterrupt) \
@property(readwrite,assign) bool interrupted; \
@end
