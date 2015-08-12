import Foundation
import Quick
import Nimble
import Carlos

private struct ValueTransformationsSharedExamplesContext {
  static let CacheToTest = "cache"
  static let InternalCache = "internalCache"
  static let Transformer = "transformer"
}

class ValueTransformationSharedExamplesConfiguration: QuickConfiguration {
  override class func configure(configuration: Configuration) {
    sharedExamples("a fetch closure with transformed values") { (sharedExampleContext: SharedExampleContext) in
      var cache: BasicCache<String, String>!
      var internalCache: CacheLevelFake<String, Int>!
      var transformer: TwoWayTransformationBox<Int, String>!
      
      beforeEach {
        cache = sharedExampleContext()[ValueTransformationsSharedExamplesContext.CacheToTest] as? BasicCache<String, String>
        internalCache = sharedExampleContext()[ValueTransformationsSharedExamplesContext.InternalCache] as? CacheLevelFake<String, Int>
        transformer = sharedExampleContext()[ValueTransformationsSharedExamplesContext.Transformer] as? TwoWayTransformationBox<Int, String>
      }
      
      context("when calling get") {
        let key = "12"
        var successValue: String?
        var failureValue: NSError?
        var fakeRequest: CacheRequest<Int>!
        
        beforeEach {
          fakeRequest = CacheRequest<Int>()
          internalCache.cacheRequestToReturn = fakeRequest
          
          cache.get(key).onSuccess({ successValue = $0 }).onFailure({ failureValue = $0 })
        }
        
        it("should forward the call to the internal cache") {
          expect(internalCache.numberOfTimesCalledGet).to(equal(1))
        }
        
        it("should pass the right key") {
          expect(internalCache.didGetKey).to(equal(key))
        }
        
        context("when the request succeeds") {
          context("when the value can be successfully transformed") {
            let value = 101
            
            beforeEach {
              fakeRequest.succeed(value)
            }
            
            it("should call the original success closure") {
              expect(successValue).notTo(beNil())
            }
            
            it("should transform the value") {
              expect(successValue).to(equal(transformer.transform(value)))
            }
          }
          
          context("when the value transformation returns nil") {
            let value = -101
            
            beforeEach {
              successValue = nil
              fakeRequest.succeed(value)
            }
            
            it("should not call the original success closure") {
              expect(successValue).to(beNil())
            }
            
            it("should call the original failure closure") {
              expect(failureValue).notTo(beNil())
            }
            
            it("should fail with the right code") {
              expect(failureValue?.code).to(equal(FetchError.ValueTransformationFailed.rawValue))
            }
          }
        }
        
        context("when the request fails") {
          let errorCode = -110
          
          beforeEach {
            fakeRequest.fail(NSError(domain: "test", code: errorCode, userInfo: nil))
          }
          
          it("should call the original failure closure") {
            expect(failureValue).notTo(beNil())
          }
          
          it("should fail with the right code") {
            expect(failureValue?.code).to(equal(errorCode))
          }
        }
      }
    }
    
    sharedExamples("a cache with transformed values") { (sharedExampleContext: SharedExampleContext) in
      var cache: BasicCache<String, String>!
      var internalCache: CacheLevelFake<String, Int>!
      var transformer: TwoWayTransformationBox<Int, String>!
      
      beforeEach {
        cache = sharedExampleContext()[ValueTransformationsSharedExamplesContext.CacheToTest] as? BasicCache<String, String>
        internalCache = sharedExampleContext()[ValueTransformationsSharedExamplesContext.InternalCache] as? CacheLevelFake<String, Int>
        transformer = sharedExampleContext()[ValueTransformationsSharedExamplesContext.Transformer] as? TwoWayTransformationBox<Int, String>
      }
      
      itBehavesLike("a fetch closure with transformed values") {
        [
          ValueTransformationsSharedExamplesContext.CacheToTest: cache,
          ValueTransformationsSharedExamplesContext.InternalCache: internalCache,
          ValueTransformationsSharedExamplesContext.Transformer: transformer
        ]
      }
      
      context("when calling set") {
        context("when the inverse transformation succeeds") {
          let key = "test key to set"
          let value = "199"
          
          beforeEach {
            cache.set(value, forKey: key)
          }
          
          it("should forward the call to the internal cache") {
            expect(internalCache.numberOfTimesCalledSet).to(equal(1))
          }
          
          it("should pass the key") {
            expect(internalCache.didSetKey).to(equal(key))
          }
          
          it("should transform the value first") {
            expect(internalCache.didSetValue).to(equal(transformer.inverseTransform(value)))
          }
        }
        
        context("when the inverse transformation fails") {
          let key = "test key to set"
          let value = "will fail"
          
          beforeEach {
            cache.set(value, forKey: key)
          }
          
          it("should not forward the call to the internal cache") {
            expect(internalCache.numberOfTimesCalledSet).to(equal(0))
          }
        }
      }
      
      context("when calling clear") {
        beforeEach {
          cache.clear()
        }
        
        it("should forward the call to the internal cache") {
          expect(internalCache.numberOfTimesCalledClear).to(equal(1))
        }
      }
      
      context("when calling onMemoryWarning") {
        beforeEach {
          cache.onMemoryWarning()
        }
        
        it("should forward the call to the internal cache") {
          expect(internalCache.numberOfTimesCalledOnMemoryWarning).to(equal(1))
        }
      }
    }
  }
}

class ValueTransformationTests: QuickSpec {
  override func spec() {
    var cache: BasicCache<String, String>!
    var internalCache: CacheLevelFake<String, Int>!
    var transformer: TwoWayTransformationBox<Int, String>!
    let forwardTransformationClosure: Int -> String? = {
      if $0 > 0 {
        return "\($0 + 1)"
      } else {
        return nil
      }
    }
    let inverseTransformationClosure: String -> Int? = {
      return $0.toInt()
    }
    
    describe("Value transformation using a transformer and a cache, with the global function") {
      beforeEach {
        internalCache = CacheLevelFake<String, Int>()
        transformer = TwoWayTransformationBox(transform: forwardTransformationClosure, inverseTransform: inverseTransformationClosure)
        cache = transformValues(internalCache, transformer)
      }
      
      itBehavesLike("a cache with transformed values") {
        [
          ValueTransformationsSharedExamplesContext.CacheToTest: cache,
          ValueTransformationsSharedExamplesContext.InternalCache: internalCache,
          ValueTransformationsSharedExamplesContext.Transformer: transformer
        ]
      }
    }
    
    describe("Value transformation using a transformer and a cache, with the operator") {
      beforeEach {
        internalCache = CacheLevelFake<String, Int>()
        transformer = TwoWayTransformationBox(transform: forwardTransformationClosure, inverseTransform: inverseTransformationClosure)
        cache = internalCache =>> transformer
      }
      
      itBehavesLike("a cache with transformed values") {
        [
          ValueTransformationsSharedExamplesContext.CacheToTest: cache,
          ValueTransformationsSharedExamplesContext.InternalCache: internalCache,
          ValueTransformationsSharedExamplesContext.Transformer: transformer
        ]
      }
    }
    
    describe("Value transformation using a transformer and a fetch closure, with the global function") {
      beforeEach {
        internalCache = CacheLevelFake<String, Int>()
        transformer = TwoWayTransformationBox(transform: forwardTransformationClosure, inverseTransform: inverseTransformationClosure)
        let fetchClosure = internalCache.get
        cache = transformValues(fetchClosure, transformer)
      }
      
      itBehavesLike("a fetch closure with transformed values") {
        [
          ValueTransformationsSharedExamplesContext.CacheToTest: cache,
          ValueTransformationsSharedExamplesContext.InternalCache: internalCache,
          ValueTransformationsSharedExamplesContext.Transformer: transformer
        ]
      }
    }
    
    describe("Value transformation using a transformer and a fetch closure, with the operator") {
      beforeEach {
        internalCache = CacheLevelFake<String, Int>()
        transformer = TwoWayTransformationBox(transform: forwardTransformationClosure, inverseTransform: inverseTransformationClosure)
        let fetchClosure = internalCache.get
        cache = fetchClosure =>> transformer
      }
      
      itBehavesLike("a fetch closure with transformed values") {
        [
          ValueTransformationsSharedExamplesContext.CacheToTest: cache,
          ValueTransformationsSharedExamplesContext.InternalCache: internalCache,
          ValueTransformationsSharedExamplesContext.Transformer: transformer
        ]
      }
    }
  }
}