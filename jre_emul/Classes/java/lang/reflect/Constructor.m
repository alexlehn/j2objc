// Copyright 2011 Google Inc. All Rights Reserved.
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
//  Constructor.m
//  JreEmulation
//
//  Created by Tom Ball on 11/11/11.
//

#import "Constructor.h"
#import "IOSReflection.h"
#import "J2ObjC_source.h"
#import "NSException+JavaThrowable.h"
#import "java/lang/AssertionError.h"
#import "java/lang/IllegalArgumentException.h"
#import "java/lang/reflect/InvocationTargetException.h"
#import "java/lang/reflect/Method.h"
#import "java/lang/reflect/Modifier.h"

#import <objc/runtime.h>

@implementation JavaLangReflectConstructor

+ (instancetype)constructorWithDeclaringClass:(IOSClass *)aClass
                                     metadata:(const J2ObjcMethodInfo *)metadata {
  return [[[JavaLangReflectConstructor alloc] initWithDeclaringClass:aClass
                                                            metadata:metadata] autorelease];
}

static id NewInstance(JavaLangReflectConstructor *self, void (^fillArgs)(NSInvocation *)) {
  const char *name = self->metadata_->selector;
  Class cls = self->class_.objcClass;
  bool isFactory = false;
  Method method = JreFindInstanceMethod(cls, name);
  if (!method) {
    // Special case for constructors declared as class methods.
    method = JreFindClassMethod(cls, name);
    isFactory = true;
  }
  NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
      [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)]];
  [invocation setSelector:sel_registerName(name)];
  fillArgs(invocation);
  id newInstance;
  @try {
    if (isFactory) {
      [invocation invokeWithTarget:cls];
      [invocation getReturnValue:&newInstance];
    } else {
      newInstance = [[cls alloc] autorelease];
      [invocation invokeWithTarget:newInstance];
    }
  }
  @catch (NSException *e) {
    @throw create_JavaLangReflectInvocationTargetException_initWithNSException_(e);
  }
  return newInstance;
}

- (id)newInstanceWithNSObjectArray:(IOSObjectArray *)initArgs {
  jint argCount = initArgs ? initArgs->size_ : 0;
  IOSObjectArray *parameterTypes = [self getParameterTypesInternal];
  if (argCount != parameterTypes->size_) {
    @throw create_JavaLangIllegalArgumentException_initWithNSString_(@"wrong number of arguments");
  }

  return NewInstance(self, ^(NSInvocation *invocation) {
    for (jint i = 0; i < argCount; i++) {
      J2ObjcRawValue arg;
      if (![parameterTypes->buffer_[i] __unboxValue:initArgs->buffer_[i] toRawValue:&arg]) {
        @throw create_JavaLangIllegalArgumentException_initWithNSString_(@"argument type mismatch");
      }
      [invocation setArgument:&arg atIndex:i + SKIPPED_ARGUMENTS];
    }
  });
}

- (id)jniNewInstance:(const J2ObjcRawValue *)args {
  return NewInstance(self, ^(NSInvocation *invocation) {
    for (int i = 0; i < [self getParameterTypesInternal]->size_; i++) {
      [invocation setArgument:(void *)&args[i] atIndex:i + SKIPPED_ARGUMENTS];
    }
  });
}

// Returns the class name, like java.lang.reflect.Constructor does.
- (NSString *)getName {
  return [class_ getName];
}

// A constructor's hash is the hash of its declaring class's name.
- (NSUInteger)hash {
  return [[class_ getName] hash];
}

- (NSString *)description {
  NSMutableString *s = [NSMutableString string];
  NSString *modifiers = JavaLangReflectModifier_toStringWithInt_(metadata_->modifiers);
  NSString *type = [[self getDeclaringClass] getName];
  [s appendFormat:@"%@ %@(", modifiers, type];
  IOSObjectArray *params = [self getParameterTypesInternal];
  jint n = params->size_;
  if (n > 0) {
    [s appendString:[(IOSClass *) params->buffer_[0] getName]];
    for (jint i = 1; i < n; i++) {
      [s appendFormat:@",%@", [(IOSClass *) params->buffer_[i] getName]];
    }
  }
  [s appendString:@")"];
  IOSObjectArray *throws = [self getExceptionTypes];
  n = throws->size_;
  if (n > 0) {
    [s appendFormat:@" throws %@", [(IOSClass *) throws->buffer_[0] getName]];
    for (jint i = 1; i < n; i++) {
      [s appendFormat:@",%@", [(IOSClass *) throws->buffer_[i] getName]];
    }
  }
  return [s description];
}

+ (const J2ObjcClassInfo *)__metadata {
  static const J2ObjcMethodInfo methods[] = {
    { "getName", "LNSString;", 0x1, -1, -1, -1, -1, -1, -1 },
    { "getModifiers", "I", 0x1, -1, -1, -1, -1, -1, -1 },
    { "getDeclaringClass", "LIOSClass;", 0x1, -1, -1, -1, 0, -1, -1 },
    { "getParameterTypes", "[LIOSClass;", 0x1, -1, -1, -1, -1, -1, -1 },
    { "getGenericParameterTypes", "[LJavaLangReflectType;", 0x1, -1, -1, -1, -1, -1, -1 },
    { "newInstanceWithNSObjectArray:", "LNSObject;", 0x81, 1, 2, 3, 4, -1, -1 },
    { "getAnnotationWithIOSClass:", "LJavaLangAnnotationAnnotation;", 0x1, 5, 6, -1, 7, -1, -1 },
    { "getDeclaredAnnotations", "[LJavaLangAnnotationAnnotation;", 0x1, -1, -1, -1, -1, -1, -1 },
    { "getParameterAnnotations", "[[LJavaLangAnnotationAnnotation;", 0x1, -1, -1, -1, -1, -1, -1 },
    { "getTypeParameters", "[LJavaLangReflectTypeVariable;", 0x1, -1, -1, -1, -1, -1, -1 },
    { "isSynthetic", "Z", 0x1, -1, -1, -1, -1, -1, -1 },
    { "getExceptionTypes", "[LIOSClass;", 0x1, -1, -1, -1, -1, -1, -1 },
    { "getGenericExceptionTypes", "[LJavaLangReflectType;", 0x1, -1, -1, -1, -1, -1, -1 },
    { "toGenericString", "LNSString;", 0x1, -1, -1, -1, -1, -1, -1 },
    { "isBridge", "Z", 0x1, -1, -1, -1, -1, -1, -1 },
    { "isVarArgs", "Z", 0x1, -1, -1, -1, -1, -1, -1 },
    { "init", NULL, 0x1, -1, -1, -1, -1, -1, -1 },
  };
  static const void *ptrTable[] = {
    "()Ljava/lang/Class<TT;>;", "newInstance", "[LNSObject;",
    "LJavaLangInstantiationException;LJavaLangIllegalAccessException;"
    "LJavaLangIllegalArgumentException;LJavaLangReflectInvocationTargetException;",
    "([Ljava/lang/Object;)TT;", "getAnnotation", "LIOSClass;",
    "<T::Ljava/lang/annotation/Annotation;>(Ljava/lang/Class<TT;>;)TT;",
    "<T:Ljava/lang/Object;>Ljava/lang/reflect/AccessibleObject;"
    "Ljava/lang/reflect/GenericDeclaration;Ljava/lang/reflect/Member;" };
  static const J2ObjcClassInfo _JavaLangReflectConstructor = {
    "Constructor", "java.lang.reflect", ptrTable, methods, NULL, 7, 0x1, 17, 0, -1, -1, -1, 8, -1
  };
  return &_JavaLangReflectConstructor;
}

@end

J2OBJC_CLASS_TYPE_LITERAL_SOURCE(JavaLangReflectConstructor)
