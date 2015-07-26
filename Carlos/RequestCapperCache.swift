import Foundation

/**
Cap requests on a given cache

:param: cache The cache you want to apply the cap to
:param: requestsCap The number of maximum concurrent requests that should be passed to the cache

:returns: An initialized RequestCapperCache (a CacheLevel itself)
*/
public func capRequests<C: CacheLevel>(cache: C, requestsCap: Int) -> RequestCapperCache<C> {
  return RequestCapperCache(internalCache: cache, requestCap: requestsCap)
}

/**
Cap requests on a given fetcher closure

:param: fetcherClosure The fetcher closure you want to apply the cap to
:param: requestsCap The number of maximum concurrent requests that should be passed to the closure

:returns: An initialized RequestCapperCache (a CacheLevel itself)
*/
public func capRequests<A, B>(fetcherClosure: (key: A) -> CacheRequest<B>, requestsCap: Int) -> RequestCapperCache<BasicCache<A, B>> {
  return capRequests(wrapClosureIntoCacheLevel(fetcherClosure), requestsCap)
}

/** 
This class keeps track of how many ongoing requests there are for a given cache and takes care of having a cap of maximum concurrent requests in case parallel access can be expensive (e.g. database or network requests).

Please note that this class is not currently thread-safe and at any time there may be a number of concurrent requests that exceeds the given requestsCap. If your application heavily relies on a maximum number of concurrent operations, please consider using other implementations, for example an NSOperationQueue or low-level locking mechanisms.
*/
public final class RequestCapperCache<C: CacheLevel>: CacheLevel {
  public typealias KeyType = C.KeyType
  public typealias OutputType = C.OutputType
  
  private let internalCache: C
  private let requestsQueue: NSOperationQueue
  
  /**
  Creates a new instance of this class
  
  :param: internalCache The cache that this instance has to manage
  :param: requestCap The maximum number of concurrent requests that the managed cache should get
  */
  public init(internalCache: C, requestCap: Int) {
    self.internalCache = internalCache
    
    self.requestsQueue = {
      let queue = NSOperationQueue()
      queue.name = "Deferred cache requests"
      queue.maxConcurrentOperationCount = requestCap
      return queue
    }()
  }
  
  /**
  Tries to get a value for the given key from the managed cache
  
  :param: key The key for the value
  
  :returns: A CacheRequest that could either be immediately executed or deferred depending on how many requests are currently pending.
  */
  public func get(key: KeyType) -> CacheRequest<OutputType> {
    let request = CacheRequest<OutputType>()
    let deferredRequestOperation = DeferredCacheRequestOperation(decoyRequest: request, key: key, cache: internalCache)
    
    if requestsQueue.operationCount >= requestsQueue.maxConcurrentOperationCount {
      Logger.log("Reached request cap, enqueueing request", .Info)
    }
    
    requestsQueue.addOperation(deferredRequestOperation)
    
    return request
  }
  
  /**
  Sets a value for the given key on the managed cache
  
  :param: key The key for the value
  
  :discussion: Calls to this method are not capped
  */
  public func set(value: OutputType, forKey key: KeyType) {
    internalCache.set(value, forKey: key)
  }
  
  /**
  Forwards the memory warning event to the managed cache
  */
  public func onMemoryWarning() {
    internalCache.onMemoryWarning()
  }
  
  /**
  Clears the managed cache
  */
  public func clear() {
    internalCache.clear()
  }
}