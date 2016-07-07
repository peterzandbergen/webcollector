use "net"
use "net/http"
use "collections"
use "time"

class GetContentHandler
  let _collector: WebCollector tag
  let _pbegin: U64


  new create(collector: WebCollector tag) =>
    _pbegin = Time.perf_begin()
    _collector = collector

  fun val apply(
    request: Payload val,
    response: Payload val
    )
  =>
    """
    Handle the response.
    """
    let pend = Time.perf_end()
    let t = (F64.from[U64](pend) - F64.from[U64](_pbegin)) / F64(1000_0000_000)
    _collector.on_handle(t, response)
    None


actor WebCollector
  let _main: Main
  let env: Env
  let client: Client
  var _sum_t: F64 = 0
  var _nurls: U32 = 0
  var _received: U32 = 0

  new create(main: Main, env': Env, client': Client) =>
    _main = main
    env = env'
    client = client'

  be apply(urls': Array[URL] val) =>
    """
    Collects the content of the payload of the given urls.
    """
    let urls = urls'
    _nurls = urls.size().u32()
    for u in urls.values() do
      let v = Array[Payload]
      let h = recover val GetContentHandler(this) end
      let p = Payload.request("GET", u, h)
      client(consume p)
    end

  be on_handle(t: F64, response: Payload val) =>
    env.out.print(
      "\n" + t.string() + ", " + 
      (_sum_t = _sum_t + t).string() + "=>" + response.proto + " " + 
      response.body_size().string() + " " + 
      response.url.string() + " " + 
      response.status.string())

      if (_received = _received + 1) == (_nurls - 1) then
        _main.done(_sum_t)
      end

  fun ref show_headers(response: Payload val) =>
    for k in response.headers().keys() do
      try
        env.out.print(k + ": " + response.headers()(k))
      end
    end


actor Main
  var _pbegin: U64 = 0
  let _env: Env

  new create(env: Env) =>
    _env = env

    repeat_read("http://localhost/pony was here", 10000)


  fun ref read_many() =>
    try 
      let auth = _env.root as AmbientAuth
      let c = Client(auth, None, true)
      // 

      let collector = WebCollector(this, _env, c)

      _pbegin = Time.perf_begin()

      collector(
        recover val 
          [
            URL.build("http://www.nu.nl"),
            URL.build("http://www.amazon.com"),
            URL.build("http://www.nrc.nl"),
            URL.build("http://www.nos.nl"),
            URL.build("http://www.netflix.com"),
            URL.build("http://www.cbs.nl"),
            URL.build("http://www.github.com"),
            URL.build("http://www.ponylang.org"),
            URL.build("http://www.golang.org"),
            URL.build("http://www.archimatetools.com"),
            URL.build("http://www.telegraaf.nl"),
            // URL.build("http://www.argeweb.nl"),
            URL.build("http://www.google.nl")
          ] 
        end
      )
    end 

  fun ref repeat_read(urls: String, n: USize) =>
    try 
      let auth = _env.root as AmbientAuth
      let c = Client(auth, None, true)
      // 

      let collector = WebCollector(this, _env, c)

      _pbegin = Time.perf_begin()

      collector(
        recover val 
          Array[URL].init(URL.build(urls), n)
        end
      )
    end 



  be done(fetch_time: F64 = 0) =>
    let pend = Time.perf_end()

    let t = (F64.from[U64](pend) - F64.from[U64](_pbegin)) / F64(1000_0000_000)

    _env.out.print("Elapsed time was: " + t.string() +
      "\nFetch time: " + fetch_time.string() +
      "\nSpeedup: " + (fetch_time - t).string())



