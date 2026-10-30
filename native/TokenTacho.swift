import Foundation
import SwiftUI
import AppKit
import Darwin
import AVFoundation
import CoreText

enum AppFont {
    static func register() {
        guard let url=Bundle.main.url(forResource:"Dosis[wght]",withExtension:"ttf") else{return}
        CTFontManagerRegisterFontsForURL(url as CFURL,.process,nil)
    }
}

// No audio is recorded or written to disk. Only a transient RMS amplitude is used.
final class MotorAudio: @unchecked Sendable {
    private let lock=NSLock()
    private var targetRPM=0.0,targetVolume=0.0
    private var motor:AVAudioEngine?
    private var microphone:AVAudioEngine?
    private var source:AVAudioSourceNode?
    func setMotor(rpm:Double,volume:Double){lock.lock();targetRPM=rpm;targetVolume=volume;lock.unlock()}
    func startMotor() throws {
        if motor != nil {return}
        let engine=AVAudioEngine()
        let format=AVAudioFormat(standardFormatWithSampleRate:44100,channels:1)!
        var phase=0.0,frequency=30.0,amplitude=0.0
        let node=AVAudioSourceNode(format:format){[weak self] _,_,frames,list in
            guard let self=self else{return noErr}
            self.lock.lock();let rpm=self.targetRPM,volume=self.targetVolume;self.lock.unlock()
            let hz=max(25,rpm/60*2)
            let gain=rpm>100 ? min(0.3,max(0,volume))*0.5:0
            let buffers=UnsafeMutableAudioBufferListPointer(list)
            for frame in 0..<Int(frames) {
                frequency += (hz-frequency)*0.001
                amplitude += (gain-amplitude)*0.0005
                phase += frequency/44100
                if phase>=1 {phase -= 1}
                let p=phase*2*Double.pi
                let value=Float((sin(p)+0.45*sin(2*p)+0.23*sin(3*p)+0.12*sin(5*p))*amplitude)
                for buffer in buffers {buffer.mData?.assumingMemoryBound(to:Float.self)[frame]=value}
            }
            return noErr
        }
        engine.attach(node);engine.connect(node,to:engine.mainMixerNode,format:format)
        try engine.start();motor=engine;source=node
    }
    func stopMotor(){setMotor(rpm:0,volume:0);motor?.stop();motor=nil;source=nil}
    func startMic(level:@escaping @Sendable (Double)->Void) throws {
        if microphone != nil {return}
        let engine=AVAudioEngine(),input=engine.inputNode
        let format=input.outputFormat(forBus:0)
        guard format.sampleRate>0 && format.channelCount>0 else {throw NSError(domain:"TokenTacho",code:1,userInfo:[NSLocalizedDescriptionKey:"Kein Audio-Eingabegerät vorhanden."])}
        input.installTap(onBus:0,bufferSize:1024,format:format){buffer,_ in
            guard let samples=buffer.floatChannelData?[0] else{return}
            let count=Int(buffer.frameLength);guard count>0 else{return}
            var sum=0.0;for i in 0..<count {sum += Double(samples[i]*samples[i])}
            let db=20*log10(max(0.000001,sqrt(sum/Double(count))))
            // A wider speech-oriented range makes ordinary desk voice levels
            // visibly move the dial instead of requiring a near-peak signal.
            level(min(1,max(0,(db+60)/30)))
        }
        do {try engine.start();microphone=engine} catch {input.removeTap(onBus:0);throw error}
    }
    func stopMic(){microphone?.inputNode.removeTap(onBus:0);microphone?.stop();microphone=nil}
    deinit{motor?.stop();microphone?.stop()}
}

struct Usage: Codable, Equatable {
    var input: Int64 = 0
    var cache: Int64 = 0
    var output: Int64 = 0
    var total: Int64 { input + output }
    // Cache is intentionally excluded from the driving model: reusing context can
    // produce a very large token delta without comparable model work.
    var driveWork: Int64 { max(0,input-cache) + output*4 }
    static func + (l: Usage, r: Usage) -> Usage { Usage(input:l.input+r.input, cache:l.cache+r.cache, output:l.output+r.output) }
    func delta(_ old: Usage) -> Usage { Usage(input:max(0,input-old.input), cache:max(0,cache-old.cache), output:max(0,output-old.output)) }
    init(input: Int64 = 0, cache: Int64 = 0, output: Int64 = 0) { self.input=input; self.cache=cache; self.output=output }
    init(_ d: [String:Any]) { input=(d["input_tokens"] as? NSNumber)?.int64Value ?? 0; cache=(d["cached_input_tokens"] as? NSNumber)?.int64Value ?? 0; output=(d["output_tokens"] as? NSNumber)?.int64Value ?? 0 }
}
struct Tick { let date: Date; let usage: Usage }
struct FeedArticle:Equatable {var title:String;var subtitle:String;var link:URL?;var image:URL?;var label:String
    static let placeholder=FeedArticle(title:"Kleine Pausen bringen große Ideen.",subtitle:"SATIRE FÜR DEN LEERLAUF",link:URL(string:"https://www.der-postillon.com"),image:nil,label:"der-postillon.com ↗")
    static func parse(_ xml:String)->FeedArticle? {
        func match(_ pattern:String,_ text:String)->String? {
            guard let regex=try? NSRegularExpression(pattern:pattern,options:[.dotMatchesLineSeparators,.caseInsensitive]) else{return nil}
            guard let found=regex.firstMatch(in:text,range:NSRange(text.startIndex...,in:text)),let range=Range(found.range(at:1),in:text) else{return nil}
            return String(text[range])
        }
        guard let item=match("<item[^>]*>(.*?)</item>",xml) else{return nil};return parseItem(item)
    }
    static func parseAll(_ xml:String)->[FeedArticle] {
        guard let regex=try? NSRegularExpression(pattern:"<item[^>]*>(.*?)</item>",options:[.dotMatchesLineSeparators,.caseInsensitive]) else{return []}
        return regex.matches(in:xml,range:NSRange(xml.startIndex...,in:xml)).compactMap {match in guard let range=Range(match.range(at:1),in:xml) else{return nil};return parseItem(String(xml[range]))}
    }
    private static func parseItem(_ item:String)->FeedArticle? {
        func match(_ pattern:String)->String? {guard let regex=try? NSRegularExpression(pattern:pattern,options:[.dotMatchesLineSeparators,.caseInsensitive]),let found=regex.firstMatch(in:item,range:NSRange(item.startIndex...,in:item)),let range=Range(found.range(at:1),in:item) else{return nil};return String(item[range])}
        guard let rawTitle=match("<title><!\\[CDATA\\[(.*?)\\]\\]></title>") ?? match("<title>(.*?)</title>") else{return nil}
        let title=rawTitle.replacingOccurrences(of:"&amp;",with:"&").replacingOccurrences(of:"&quot;",with:"\"")
        let description=match("<description><!\\[CDATA\\[(.*?)\\]\\]></description>") ?? ""
        func descriptionMatch(_ pattern:String)->String? {guard let regex=try? NSRegularExpression(pattern:pattern,options:[.dotMatchesLineSeparators,.caseInsensitive]),let found=regex.firstMatch(in:description,range:NSRange(description.startIndex...,in:description)),let range=Range(found.range(at:1),in:description) else{return nil};return String(description[range])}
        let articleLink=descriptionMatch("<a[^>]+href=\"(https?://www\\.der-postillon[^\"]+)")
        let fallbackLink=match("<link>(.*?)</link>")
        // The feed prepends a one-pixel tracking image; find the real Blogger
        // preview anywhere in the description instead of assuming the first img.
        let imageLink=descriptionMatch("(https?://blogger\\.googleusercontent[^\"<>\\s]+)")
        // Blogger serves a dedicated small rendition at the same URL. The feed's
        // original images are several megabytes, which cannot reliably finish
        // before a 2.5-second card advances. This remains the article's real
        // image; only its delivery size changes to the card's actual resolution.
        let cardImageLink:String?
        if let imageLink,let range=imageLink.range(of:"/s[0-9]+/",options:.regularExpression) {
            cardImageLink=imageLink.replacingCharacters(in:range,with:"/w480-h270/")
        } else {cardImageLink=imageLink}
        let link=URL(string:articleLink ?? fallbackLink ?? "")
        let host=link?.host?.replacingOccurrences(of:"www.",with:"") ?? "Source"
        let source=host.contains("postillon") ? "DER POSTILLON · SATIRE" : "RSS · \(host.uppercased())"
        return FeedArticle(title:title,subtitle:source,link:link,image:URL(string:cardImageLink ?? ""),label:"\(host) ↗")
    }
}
struct FeedPreset:Identifiable {
    let name:String
    let url:String
    var id:String {url}
    static let suggestions=[
        FeedPreset(name:"DER POSTILLON",url:"https://www.der-postillon.com/feeds/posts/default?alt=rss"),
        FeedPreset(name:"TITANIC",url:"https://www.titanic-magazin.de/feed/"),
        FeedPreset(name:"DIE TAGESPRESSE",url:"https://dietagespresse.com/feed/"),
        FeedPreset(name:"THE ONION",url:"https://www.theonion.com/rss"),
        FeedPreset(name:"NEWSTHUMP",url:"https://newsthump.com/feed/")
    ]
    static func customName(_ url:String)->String {URL(string:url)?.host?.replacingOccurrences(of:"www.",with:"").uppercased() ?? "CUSTOM RSS"}
}
final class Session {
    var id: String; var cwd = ""; var title = ""; var forked = false
    var activeAt:Date?
    var last: Usage?; var ticks: [Tick] = []; var warnings = 0
    init(_ id: String) { self.id=id }
    func consume(_ obj: [String:Any]) {
        guard let p=obj["payload"] as? [String:Any] else { return }
        if obj["type"] as? String == "session_meta" {
            id=p["id"] as? String ?? id; cwd=p["cwd"] as? String ?? cwd
            forked=p["forked_from_id"] as? String != nil
            return
        }
        if obj["type"] as? String == "event_msg" {
            if p["type"] as? String == "task_started" {activeAt=Session.date(obj["timestamp"] as? String ?? "")}
            if ["task_complete","turn_aborted"].contains(p["type"] as? String ?? "") {activeAt=nil}
        }
        guard obj["type"] as? String == "event_msg", p["type"] as? String == "token_count", let info=p["info"] as? [String:Any], let d=info["total_token_usage"] as? [String:Any], let stamp=obj["timestamp"] as? String, let date=Session.date(stamp) else { return }
        let current=Usage(d)
        guard current.input>=0, current.output>=0, current.cache>=0, current.cache<=current.input else { warnings += 1; return }
        if let previous=last {
            // Cumulative high-water marks: duplicate / stale snapshots never count again.
            if current.input < previous.input || current.output < previous.output { warnings += 1; return }
            let change=current.delta(previous)
            last=current
            if change.total>0 { ticks.append(Tick(date:date,usage:change)) }
        } else {
            last=current
            // Inherited history is excluded; start counting only after the fork baseline.
            if !forked && current.total>0 { ticks.append(Tick(date:date,usage:current)) }
        }
    }
    static let iso = ISO8601DateFormatter()
    static let fractional: ISO8601DateFormatter = { let f=ISO8601DateFormatter(); f.formatOptions=[.withInternetDateTime,.withFractionalSeconds]; return f }()
    static func date(_ s:String)->Date? { fractional.date(from:s) ?? iso.date(from:s) }
}
func newline(_ data:Data,_ start:Int)->Int? {
    data.withUnsafeBytes { raw in
        guard let base=raw.baseAddress else{return nil}
        let offset=start-data.startIndex
        guard let found=memchr(base.advanced(by:offset),10,raw.count-offset) else{return nil}
        return data.startIndex+base.distance(to:found)
    }
}
func containsMarker(_ data:Data.SubSequence,_ marker:String)->Bool {
    data.withUnsafeBytes { raw in
        marker.utf8CString.withUnsafeBytes { text in
            guard let b=raw.baseAddress,let t=text.baseAddress else{return false}
            return memmem(b,raw.count,t,text.count-1) != nil
        }
    }
}
final class Tail {
    let url: URL; var offset: UInt64=0; var pending=Data(); var size: UInt64=0; var modified=Date.distantPast
    var session: Session
    init(_ u:URL) {url=u;session=Session(u.deletingPathExtension().lastPathComponent)}
    func read() throws {
        let a=try FileManager.default.attributesOfItem(atPath:url.path)
        let length=(a[.size] as? NSNumber)?.uint64Value ?? 0
        let m=a[.modificationDate] as? Date ?? .distantPast
        if length==size && m==modified {return}
        if length<offset || (length==size && m != modified) {offset=0;pending=Data();session=Session(url.lastPathComponent)}
        let handle=try FileHandle(forReadingFrom:url); defer {try? handle.close()}
        try handle.seek(toOffset:offset)
        while let chunk=try handle.read(upToCount:1024*1024), !chunk.isEmpty {
            offset += UInt64(chunk.count);pending.append(chunk)
            var start=pending.startIndex
            while start < pending.endIndex, let end=newline(pending,start) {
                let line=pending[start..<end]
                start=pending.index(after:end)
                if containsMarker(line,"token_count") || containsMarker(line,"session_meta") || containsMarker(line,"task_started") || containsMarker(line,"task_complete") || containsMarker(line,"turn_aborted") {
                    if let obj=(try? JSONSerialization.jsonObject(with:line)) as? [String:Any] {session.consume(obj)}
                }
            }
            if start>pending.startIndex {pending.removeSubrange(pending.startIndex..<start)}
        }
        size=length;modified=m
    }
}
struct Snapshot {
    var active=false
    var sessions:[SessionRow]=[];var total=Usage();var today=Usage();var rate:Int64=0;var driveRate:Int64=0;var driveWork:Int64=0
    var latest:Date?;var error="";var warnings=0;var files=0
}
struct SessionRow:Identifiable {let id:String;let title:String;let cwd:String;let total:Usage;let today:Usage;let rate:Int64;let driveRate:Int64;let driveWork:Int64;let latest:Date?}
// Access is confined to one serial queue (or the command-line test thread).
final class Reader: @unchecked Sendable {
    var tails:[String:Tail]=[:]
    func scan(home:URL)->Snapshot {
        var result=Snapshot();var seen=Set<String>(); var discovered=Set<String>();var failures=0
        for dir in ["sessions","archived_sessions"] {
            let base=home.appendingPathComponent(dir)
            guard let e=FileManager.default.enumerator(at:base,includingPropertiesForKeys:[.isRegularFileKey],options:[.skipsHiddenFiles]) else {continue}
            for case let url as URL in e where url.pathExtension=="jsonl" {
                discovered.insert(url.path)
                let tail=tails[url.path] ?? Tail(url);tails[url.path]=tail
                do {try tail.read()} catch {failures += 1;continue}
                let s=tail.session
                guard seen.insert(s.id).inserted else {continue}
                result.files += 1;result.warnings += s.warnings
                if let active=s.activeAt, Date().timeIntervalSince(active)<1800 {result.active=true}
                let now=Date(),cutoff=now.addingTimeInterval(-10)
                var total=Usage(),today=Usage();var rate:Int64=0;var driveRate:Int64=0;var totalDriveWork:Int64=0;var latest:Date?
                for t in s.ticks {
                    total=total+t.usage
                    totalDriveWork += t.usage.driveWork
                    if Calendar.current.isDate(t.date,inSameDayAs:now) {today=today+t.usage}
                    if t.date>cutoff && t.date<=now {rate += t.usage.total;driveRate += t.usage.driveWork}
                    if latest == nil || t.date>latest! {latest=t.date}
                }
                result.total=result.total+total;result.today=result.today+today;result.rate += rate/10;result.driveRate += driveRate/10;result.driveWork += totalDriveWork
                if let date=latest, result.latest == nil || date>result.latest! {result.latest=date}
                result.sessions.append(SessionRow(id:s.id,title:s.title.isEmpty ? String(s.id.prefix(8)) : s.title,cwd:s.cwd,total:total,today:today,rate:rate/10,driveRate:driveRate/10,driveWork:totalDriveWork,latest:latest))
            }
        }
        tails=tails.filter{discovered.contains($0.key)}
        // Only titles and IDs are read; no message contents are kept by the app.
        if let data=try? String(contentsOf:home.appendingPathComponent("session_index.jsonl"),encoding:.utf8) {
            var titles:[String:String]=[:]
            for line in data.split(separator:"\n") {
                if let d=line.data(using:.utf8),let o=(try? JSONSerialization.jsonObject(with:d)) as? [String:Any],let id=o["id"] as? String,let name=o["thread_name"] as? String {titles[id]=name}
            }
            result.sessions=result.sessions.map{ r in SessionRow(id:r.id,title:titles[r.id] ?? r.title,cwd:r.cwd,total:r.total,today:r.today,rate:r.rate,driveRate:r.driveRate,driveWork:r.driveWork,latest:r.latest) }
        }
        result.sessions.sort{($0.latest ?? .distantPast)>($1.latest ?? .distantPast)}
        if result.files==0 {result.error="No readable Codex logs found."}
        if failures>0 {result.error="\(failures) Dateien konnten nicht gelesen werden. Anzeige möglicherweise unvollständig."}
        return result
    }
}
@MainActor final class Meter:ObservableObject {
    @Published var snapshot=Snapshot();@Published var selection="all";@Published var today=false
    @Published var floating=false {didSet{for w in NSApp.windows{w.level=floating ? .floating : .normal}}}
    @Published var showDetails=false
    @Published var scale=80_000.0
    @Published var needle=0.0
    var velocity=0.0
    @Published var speedNeedle=0.0
    var speedNeedleVelocity=0.0
    var motionTimer:Timer?
    @Published var roadDistance=0.0
    @Published var displayedTotal=0.0
    var counterFrom=0.0,counterTarget=0.0
    var counterStarted=Date.distantPast
    var counterReady=false
    var counterDuration=2.4
    var counterDeadline=Date.distantPast
    var counterLastFrame=Date.distantPast
    var liveCounterFrame=Date.distantPast
    var bendsEnabled=true
    var roadBend:Double {bendsEnabled ? sin(roadDistance*0.65)*0.82+sin(roadDistance*0.23)*0.12:0}
    var visibleTotal:Int64 {counterReady ? Int64(displayedTotal.rounded(.down)) : ((UserDefaults.standard.object(forKey:displayTotalKey) as? NSNumber)?.int64Value ?? 0)}
    func receiveCounter(_ total:Int64,now:Date=Date()){
        let value=Double(total)
        if !counterReady || value<counterTarget {displayedTotal=value;counterFrom=value;counterTarget=value;counterReady=true;counterDeadline=now;counterLastFrame=now;return}
        guard value>counterTarget else{return}
        counterTarget=value
        counterDeadline=now.addingTimeInterval(2.4)
    }
    func animateCounter(now:Date){
        guard counterReady else{return}
        guard displayedTotal != counterTarget else{return}
        if displayedTotal > counterTarget {
            let elapsed=max(0,now.timeIntervalSince(counterLastFrame));counterLastFrame=now
            let step=max(1,(displayedTotal-counterTarget)*min(1,elapsed/0.8))
            displayedTotal=max(counterTarget,displayedTotal-step)
            return
        }
        if now >= counterDeadline {displayedTotal=counterTarget;counterLastFrame=now;return}
        let elapsed=max(0,now.timeIntervalSince(counterLastFrame));counterLastFrame=now
        let remaining=max(0.001,counterDeadline.timeIntervalSince(now))
        let step=(counterTarget-displayedTotal)*min(1,elapsed/(remaining+elapsed))
        displayedTotal=min(counterTarget,displayedTotal+max(1,step))
    }
    @Published var speed=0.0
    @Published var rpm=0.0
    @Published var loadNeedle=0.0
    @Published var gear=1
    @Published var micOn=false
    @Published var micLevel=0.0
    @Published var audioMessage=""
    @Published var soundOn=UserDefaults.standard.bool(forKey:"soundOn") {didSet{UserDefaults.standard.set(soundOn,forKey:"soundOn");configureSound()}}
    @Published var volume=UserDefaults.standard.object(forKey:"volume") as? Double ?? 0.12 {didSet{UserDefaults.standard.set(volume,forKey:"volume")}}
    @Published var tripBaseline:Int64?=nil
    @Published var feed=FeedArticle.placeholder
    @Published var feedItems:[FeedArticle]=[]
    @Published var feedIndex=0
    @Published var feedImage:NSImage?=nil
    @Published var feedImageLoading=false
    @Published var feedImageStatus=""
    @Published var feedURL=UserDefaults.standard.string(forKey:"feedURL") ?? "https://www.der-postillon.com/feeds/posts/default?alt=rss"
    @Published var feedDraft=""
    @Published var feedValidation=""
    @Published var customFeedURLs=UserDefaults.standard.stringArray(forKey:"customFeedURLs") ?? []
    var feedPages:[Int:[FeedArticle]] = [:]
    var feedLoadID=UUID()
    var feedHistory:[FeedArticle]=[]
    var feedDirection=1
    let feedImageCache=NSCache<NSURL,NSImage>()
    var imageWaiters:[String:[(NSImage?)->Void]] = [:]
    @Published var fuelBudget=UserDefaults.standard.object(forKey:"fuelBudget") as? Double ?? 50_000 {didSet{UserDefaults.standard.set(fuelBudget,forKey:"fuelBudget")}}
    @Published var fuelBaseline:Int64?=nil
    @Published var tripDisplayed=0.0
    var tripResetStarted=Date.distantPast
    var tripResetFrom:Int64=0
    var tripResetTo:Int64=0
    var tripResetBaseline:Int64=0
    var tripResetting=false
    var tripCounterTarget=0.0
    var tripCounterReady=false
    var tripCounterDeadline=Date.distantPast
    var tripCounterLastFrame=Date.distantPast
    var liveTripFrame=Date.distantPast
    var shiftUntil=Date.distantPast
    var wasActive=false
    var taskWorkBaseline:Int64?=nil
    var lastRPMTarget=0.0
    var driveVelocity=0.0
    let audio=MotorAudio()
    var trip:Int64 {max(0,snapshot.total.total-(tripBaseline ?? snapshot.total.total))}
    var visibleTrip:Int64 {tripCounterReady ? Int64(tripDisplayed.rounded(.down)) : ((UserDefaults.standard.object(forKey:displayTripKey) as? NSNumber)?.int64Value ?? 0)}
    var displayTotalKey:String {"display-total:"+home.path}
    var displayTripKey:String {"display-trip:"+home.path}
    func preloadDisplays(){
        if let total=(UserDefaults.standard.object(forKey:displayTotalKey) as? NSNumber)?.int64Value {displayedTotal=Double(total);counterFrom=Double(total);counterTarget=Double(total);counterReady=true;counterDeadline=Date();counterLastFrame=Date()}
        if let trip=(UserDefaults.standard.object(forKey:displayTripKey) as? NSNumber)?.int64Value {tripDisplayed=Double(trip);tripCounterTarget=Double(trip);tripCounterReady=true;tripCounterDeadline=Date();tripCounterLastFrame=Date()}
    }
    func resetTrip(){
        guard !tripResetting,trip>0 else{return}
        tripResetting=true;tripResetStarted=Date();tripResetFrom=trip
        tripResetTo=((tripResetFrom/100_000)+1)*100_000
        tripResetBaseline=snapshot.total.total
    }
    // Same animation kernel as TOTAL; the only difference is the reset baseline.
    func receiveTrip(_ value:Int64,now:Date=Date()) {
        let target=Double(value)
        if !tripCounterReady || target<tripCounterTarget {tripDisplayed=target;tripCounterTarget=target;tripCounterReady=true;tripCounterDeadline=now;tripCounterLastFrame=now;return}
        guard target>tripCounterTarget else{return}
        tripCounterTarget=target;tripCounterDeadline=now.addingTimeInterval(2.4)
    }
    func animateTrip(now:Date){
        guard tripResetting else {
            guard tripCounterReady,tripDisplayed != tripCounterTarget else{return}
            if tripDisplayed>tripCounterTarget {let elapsed=max(0,now.timeIntervalSince(tripCounterLastFrame));tripCounterLastFrame=now;let step=max(1,(tripDisplayed-tripCounterTarget)*min(1,elapsed/0.8));tripDisplayed=max(tripCounterTarget,tripDisplayed-step);return}
            if now>=tripCounterDeadline {tripDisplayed=tripCounterTarget;tripCounterLastFrame=now;return}
            let elapsed=max(0,now.timeIntervalSince(tripCounterLastFrame));tripCounterLastFrame=now
            let remaining=max(0.001,tripCounterDeadline.timeIntervalSince(now))
            let step=(tripCounterTarget-tripDisplayed)*min(1,elapsed/(remaining+elapsed))
            tripDisplayed=min(tripCounterTarget,tripDisplayed+max(1,step))
            return
        }
        let t=min(1,max(0,now.timeIntervalSince(tripResetStarted)/0.9))
        let eased=t*t*(3-2*t)
        let rolling=Int64((Double(tripResetFrom)+Double(tripResetTo-tripResetFrom)*eased).rounded(.down))
        tripDisplayed=Double(rolling % 100_000)
        if t >= 1 {tripBaseline=tripResetBaseline;saveTrip();tripDisplayed=0;tripCounterTarget=0;tripCounterReady=true;tripCounterDeadline=now;tripCounterLastFrame=now;UserDefaults.standard.set(NSNumber(value:0),forKey:displayTripKey);tripResetting=false}
    }
    func saveTrip(){if let baseline=tripBaseline {UserDefaults.standard.set(NSNumber(value:baseline),forKey:"trip:"+home.path)}}
    func setFeedURL(_ source:String){feedURL=source;feedDraft=source;UserDefaults.standard.set(source,forKey:"feedURL");feedItems=[];feedIndex=0;feedHistory=[];loadFeed()}
    var feedPresets:[FeedPreset] {customFeedURLs.map{FeedPreset(name:FeedPreset.customName($0),url:$0)}+FeedPreset.suggestions}
    func rememberCustomFeed(_ source:String){guard !FeedPreset.suggestions.contains(where:{$0.url==source}),!customFeedURLs.contains(source) else{return};customFeedURLs.insert(source,at:0);UserDefaults.standard.set(customFeedURLs,forKey:"customFeedURLs")}
    func validateFeedDraft(saveCustom:Bool=true){
        let source=feedDraft.trimmingCharacters(in:.whitespacesAndNewlines)
        guard let url=URL(string:source),url.scheme=="https" || url.scheme=="http" else {feedValidation="Enter a complete RSS URL.";return}
        feedValidation="Checking source …"
        DispatchQueue.global(qos:.utility).async {
            let gate=DispatchSemaphore(value:0);var data:Data?
            var request=URLRequest(url:url);request.timeoutInterval=15;request.setValue("Token Drive RSS Reader/1.0",forHTTPHeaderField:"User-Agent")
            URLSession.shared.dataTask(with:request){responseData,_,_ in data=responseData;gate.signal()}.resume()
            _=gate.wait(timeout:.now()+17)
            let articles=data.flatMap{String(data:$0,encoding:.utf8)}.map(FeedArticle.parseAll) ?? []
            DispatchQueue.main.async {
                guard self.feedDraft.trimmingCharacters(in:.whitespacesAndNewlines)==source else{return}
                guard let sample=articles.first else {self.feedValidation="No readable RSS entries found.";return}
                self.feedValidation="Ready · \(articles.count) entries · \(sample.title.prefix(42))"
                if saveCustom {self.rememberCustomFeed(source)}
                self.setFeedURL(source)
            }
        }
    }
    func usePreset(_ preset:FeedPreset){feedDraft=preset.url;validateFeedDraft(saveCustom:false)}
    var fuelUsed:Int64 {max(0,snapshot.total.total-(fuelBaseline ?? snapshot.total.total))}
    var fuelFraction:Double {max(0,min(1,1-Double(fuelUsed)/fuelBudget))}
    var fuelMinutes:Int? {guard snapshot.rate>0 else{return nil};return max(0,Int((Double(fuelBudget)-Double(fuelUsed))/Double(snapshot.rate)/60))}
    func resetFuel(){fuelBaseline=snapshot.total.total;UserDefaults.standard.set(NSNumber(value:fuelBaseline!),forKey:"fuel:"+home.path);UserDefaults.standard.set("0.10",forKey:"fuelVersion")}
    func loadFeed(){
        guard var components=URLComponents(string:feedURL) else{return}
        let isPostillon=components.host?.contains("der-postillon.com")==true
        components.queryItems=(components.queryItems ?? []).filter{$0.name != "max-results" && $0.name != "start-index"}
        let urls:[URL]
        if isPostillon {
            urls=[1,21,41].compactMap {start in var page=components;page.queryItems=(page.queryItems ?? [])+[URLQueryItem(name:"max-results",value:"20"),URLQueryItem(name:"start-index",value:String(start))];return page.url}
        } else {urls=components.url.map{[$0]} ?? []}
        guard !urls.isEmpty else{return}
        let loadID=UUID();feedLoadID=loadID;feedPages=[:]
        for (index,url) in urls.enumerated() {
            var request=URLRequest(url:url);request.timeoutInterval=15;request.setValue("Token Drive RSS Reader/1.0",forHTTPHeaderField:"User-Agent")
            URLSession.shared.dataTask(with:request){data,response,_ in guard let data,let response=response as? HTTPURLResponse,response.statusCode==200,let text=String(data:data,encoding:.utf8) else{return};let articles=FeedArticle.parseAll(text);guard !articles.isEmpty else{return};DispatchQueue.main.async {guard self.feedLoadID==loadID else{return};self.feedPages[index]=articles;self.applyFeedPages()}}.resume()
        }
    }
    func applyFeedPages(){
        let visible=Array(feedPages.keys.sorted().flatMap{feedPages[$0] ?? []}.prefix(50));guard !visible.isEmpty else{return}
        let currentLink=feed.link
        let merged=(visible+feedItems).reduce(into:[FeedArticle]()){items,article in if !items.contains(where:{$0.link==article.link}) {items.append(article)}}
        feedItems=Array(merged.prefix(50))
        if let currentLink,let preserved=feedItems.firstIndex(where:{$0.link==currentLink}) {feedIndex=preserved} else {feedIndex=0;feedHistory=[];feed=feedItems[0];loadFeedImage()}
    }
    func showFeed(_ index:Int,direction:Int){guard feedItems.indices.contains(index) else{return};withAnimation(.easeInOut(duration:0.32)){feedDirection=direction;feedIndex=index;feed=feedItems[index]};feedImage=nil;feedImageLoading=false}
    func advanceFeed(){guard !feedItems.isEmpty else{return};feedHistory.append(feed);feedHistory=Array(feedHistory.suffix(2));showFeed((feedIndex+1)%feedItems.count,direction:1)}
    func previousFeed(){guard let previous=feedHistory.popLast(),let index=feedItems.firstIndex(where:{$0.link==previous.link}) else{return};showFeed(index,direction:-1)}
    func requestImage(_ url:URL,completion:@escaping (NSImage?)->Void){
        if let cached=feedImageCache.object(forKey:url as NSURL){completion(cached);return}
        let key=url.absoluteString,waiting=imageWaiters[key] != nil
        imageWaiters[key,default:[]].append(completion)
        guard !waiting else{return}
        // This deliberately uses the same bounded worker pattern as --feed-diagnose.
        // It avoids relying on a transient URLSession callback during card changes.
        DispatchQueue.global(qos:.utility).async {
            let gate=DispatchSemaphore(value:0);var result:Data?
            var request=URLRequest(url:url);request.timeoutInterval=20
            request.setValue("Token Drive RSS Reader/1.0",forHTTPHeaderField:"User-Agent")
            URLSession.shared.dataTask(with:request){data,_,_ in result=data;gate.signal()}.resume()
            _=gate.wait(timeout:.now()+22)
            let image=result.flatMap(NSImage.init(data:))
            DispatchQueue.main.async {
                if let image {self.feedImageCache.setObject(image,forKey:url as NSURL)}
                let callbacks=self.imageWaiters.removeValue(forKey:key) ?? []
                callbacks.forEach{$0(image)}
            }
        }
    }
    func prefetchUpcomingImages(){guard feedItems.count>1 else{return};for offset in 1...min(2,feedItems.count-1) {if let url=feedItems[(feedIndex+offset)%feedItems.count].image {requestImage(url){_ in}}}}
    func loadFeedImage(){
        let expectedLink=feed.link;feedImage=nil;feedImageLoading=true
        guard let url=feed.image else{feedImageLoading=false;feedImageStatus="Kein Bild im RSS-Artikel";UserDefaults.standard.set(feedImageStatus,forKey:"feedImageStatus");return}
        feedImageStatus="Lade Bild …";UserDefaults.standard.set(feedImageStatus,forKey:"feedImageStatus")
        prefetchUpcomingImages()
        requestImage(url){image in
            guard self.feed.link==expectedLink else{return}
            self.feedImage=image;self.feedImageLoading=false
            self.feedImageStatus=image == nil ? "Bildabruf oder Dekodierung fehlgeschlagen" : "Bild geladen"
            UserDefaults.standard.set(self.feedImageStatus,forKey:"feedImageStatus")
            UserDefaults.standard.set(url.absoluteString,forKey:"feedImageURL")
        }
    }
    var liveAudio=false
    var motorRouted=false
    // Microphone input always wins while Codex is idle. Previously a coasting
    // engine could keep the microphone paused even after the user enabled it.
    var wantsMotor:Bool {soundOn && !micOn && (snapshot.active || speed>3)}
    func configureSound(){
        motorRouted=wantsMotor
        guard liveAudio else {return}
        if motorRouted {
            audio.stopMic();micLevel=0
            do {try audio.startMotor();audioMessage=""}
            catch {audioMessage="Engine sound unavailable: \(error.localizedDescription)";soundOn=false}
        } else {
            audio.stopMotor()
            if micOn {
                do {try audio.startMic {level in DispatchQueue.main.async{if self.micOn && !self.motorRouted {self.micLevel=level}}};audioMessage=""}
                catch {micOn=false;audioMessage="Microphone could not start: \(error.localizedDescription)"}
            }
        }
    }
    func toggleMic(){
        if micOn {audio.stopMic();micOn=false;micLevel=0;audioMessage="";configureSound();return}
        AVCaptureDevice.requestAccess(for:.audio){allowed in DispatchQueue.main.async {
            guard allowed else {self.audioMessage="Microphone access was not granted. Enable it in macOS Privacy & Security.";return}
            self.micOn=true;self.configureSound()
        }}
    }
    var micStatus:String {guard micOn else{return "MICROPHONE · OFF"};return "MICROPHONE · LISTENING · \(Int((micLevel*100).rounded()))%"}
    @Published var busy=false
    @Published var home:URL
    @Published var sourceAuthorized=false
    @Published var lastScanAt:Date?=nil
    private var sourceAccessing=false
    let reader=Reader();let queue=DispatchQueue(label:"local.token.reader",qos:.utility)
    var timer:Timer?;var feedTimer:Timer?;var feedAdvanceTimer:Timer?
    init(start:Bool=true){let fallback=FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex");var stale=false;if let bookmark=UserDefaults.standard.data(forKey:"codexFolderBookmark"),let selected=try? URL(resolvingBookmarkData:bookmark,options:[.withSecurityScope],relativeTo:nil,bookmarkDataIsStale:&stale) {home=selected;sourceAccessing=selected.startAccessingSecurityScopedResource();sourceAuthorized=sourceAccessing || FileManager.default.fileExists(atPath:selected.path);if stale,let renewed=try? selected.bookmarkData(options:[.withSecurityScope,.securityScopeAllowOnlyReadAccess],includingResourceValuesForKeys:nil,relativeTo:nil){UserDefaults.standard.set(renewed,forKey:"codexFolderBookmark")}} else {home=fallback;sourceAuthorized=FileManager.default.fileExists(atPath:fallback.path)};feedDraft=feedURL;preloadDisplays();if feedURL.contains("feedburner") {feedURL="https://www.der-postillon.com/feeds/posts/default?alt=rss";feedDraft=feedURL;UserDefaults.standard.set(feedURL,forKey:"feedURL")};liveAudio=start;if start {configureSound();refresh();loadFeed();timer=Timer.scheduledTimer(withTimeInterval:0.25,repeats:true){[weak self] _ in Task{@MainActor in self?.refresh()}};feedTimer=Timer.scheduledTimer(withTimeInterval:300,repeats:true){[weak self] _ in Task{@MainActor in self?.loadFeed()}};feedAdvanceTimer=Timer.scheduledTimer(withTimeInterval:3.8,repeats:true){[weak self] _ in Task{@MainActor in self?.advanceFeed()}}
        motionTimer=Timer.scheduledTimer(withTimeInterval:1.0/30,repeats:true){[weak self] _ in Task{@MainActor in self?.stepNeedle()}}
    }}
    func stepNeedle(now:Date=Date()){
        let dt=1.0/30,active=snapshot.active
        if active && !wasActive {gear=1;shiftUntil = .distantPast;taskWorkBaseline=snapshot.driveWork}
        if !active {taskWorkBaseline=nil}
        wasActive=active
        roadDistance += speed*dt/180
        let curvature=min(1,abs(roadBend))
        let effort=driveEffort
        let cruise=75+205*effort
        let cornerLimit=300-215*pow(curvature,1.3)
        let targetSpeed=active ? min(cruise*(1-0.22*curvature),cornerLimit):0
        // A little engine-linked motion keeps FAHRSTIL alive during light work,
        // while the upper range remains reserved for measured model effort.
        let kineticLoad=min(0.22,max(0,0.035+speed/300*0.16+rpm/9000*0.16+sin(roadDistance*5)*0.012))
        let loadTarget=active ? max(effort,kineticLoad) : 0
        loadNeedle += (loadTarget-loadNeedle)*0.045
        animateCounter(now:now)
        animateTrip(now:now)
        // Logs can arrive in batches. During a live task, show a small bounded
        // provisional roll; the next measured snapshot replaces it, and completion
        // always settles both displays back to the exact measured targets.
        if active && counterReady {
            let totalDT=liveCounterFrame == .distantPast ? 0: min(0.2,max(0,now.timeIntervalSince(liveCounterFrame)));liveCounterFrame=now
            let visualRate=max(35,min(700,Double(rate)>0 ? Double(rate)*0.16:rpm/9))
            displayedTotal=min(counterTarget+1_000,displayedTotal+visualRate*totalDT)
            let tripDT=liveTripFrame == .distantPast ? 0: min(0.2,max(0,now.timeIntervalSince(liveTripFrame)));liveTripFrame=now
            tripDisplayed=min(tripCounterTarget+1_000,tripDisplayed+visualRate*tripDT)
        } else {liveCounterFrame = .distantPast;liveTripFrame = .distantPast}
        // Deliberately playful driving simulation, not a physical token conversion.
        let acceleration=active ? min(24,max(-32,(targetSpeed-speed)*0.48)):max(-35,-speed*0.65)
        speed=max(0,min(300,speed+acceleration*dt))
        // The speed needle has its own light inertia, so acceleration produces a
        // short, physical-looking overshoot before it settles on road speed.
        speedNeedleVelocity += ((speed-speedNeedle)*42-speedNeedleVelocity*7.4)*dt + acceleration*0.028
        speedNeedle=max(0,min(305,speedNeedle+speedNeedleVelocity*dt))
        let thresholds=[0.0,36,74,122,180,245]
        if active && gear<6 && speed>thresholds[gear] && acceleration>1 && curvature<0.65 && now>shiftUntil {gear += 1;shiftUntil=now.addingTimeInterval(0.6)}
        if gear>1 && speed<thresholds[gear-1]-12 && now>shiftUntil {gear -= 1;shiftUntil=now.addingTimeInterval(0.5)}
        if active && bendsEnabled && curvature>0.68 && gear==3 && speed<82 && now>shiftUntil {gear=2;shiftUntil=now.addingTimeInterval(0.6)}
        let base=thresholds[gear-1]
        let span=gear<6 ? thresholds[gear]-base:70
        let accelerationRPM=1800+max(0,(speed-base)/span)*3400
        var targetRPM=active ? accelerationRPM:(speed>3 ? max(900,rpm-2500*dt):0)
        if active && abs(targetSpeed-speed)<7 {targetRPM=1900+speed*9}
        if active && bendsEnabled {targetRPM += max(0,acceleration)*45 + 140*sin(roadDistance*2)}
        if now<shiftUntil {targetRPM=max(1400,targetRPM-1500)}
        // Manual microphone mode owns the engine response, including while a
        // Codex task is active. The synthesized motor is stopped in this mode,
        // so this does not create an output-to-input feedback loop.
        if micOn {targetRPM=max(targetRPM,900+micLevel*7_100+sin(now.timeIntervalSinceReferenceDate*18)*micLevel*260)}
        targetRPM=min(8500,max(0,targetRPM))
        rpm += (targetRPM-rpm)*min(1,dt*(now<shiftUntil ? 10:4))
        let target=min(1,max(0,rpm/9000))
        let rpmKick=max(-0.35,min(0.45,(targetRPM-lastRPMTarget)/5_500))
        velocity += ((target-needle)*48-velocity*8.6)*dt+rpmKick*dt
        needle=min(1.025,max(0,needle+velocity*dt))
        lastRPMTarget=targetRPM
        if wantsMotor != motorRouted {configureSound()}
        audio.setMotor(rpm:rpm,volume:motorRouted ? volume:0)
    }
    func dock(top:Bool){
        floating=true
        guard let w=NSApp.windows.first(where:{$0.title=="Token Tacho"}),let screen=w.screen ?? NSScreen.main else{return}
        let frame=screen.visibleFrame
        w.setFrameOrigin(NSPoint(x:frame.midX-w.frame.width/2,y:top ? frame.maxY-w.frame.height-8:frame.minY+8))
    }
    var localSourceStatus:String {guard sourceAuthorized else{return "TOKEN SOURCE · SELECT LOCAL .CODEX FOLDER"};if busy{return "CODEX SOURCE · READING…"};if !snapshot.error.isEmpty{return "CODEX SOURCE · \(snapshot.error.uppercased())"};guard snapshot.files>0 else{return "CODEX SOURCE · NO READABLE LOGS FOUND"};let event=snapshot.latest?.formatted(date:.omitted,time:.shortened) ?? "—";return "CODEX SOURCE · \(snapshot.files) LOGS · LAST EVENT \(event)"}
    var localSourceHint:String {guard sourceAuthorized else{return "No local ~/.codex folder was found. Use Codex Folder to choose one."};let checked=lastScanAt?.formatted(date:.omitted,time:.shortened) ?? "not checked yet";return "Reading: \(home.path) · checked \(checked)"}
    func refresh(){guard sourceAuthorized else {snapshot.error="Select your local .codex folder to show tokens.";return};guard !busy else{return};busy=true;let source=home;let localReader=reader;queue.async {let s=localReader.scan(home:source);DispatchQueue.main.async{if self.home != source {self.busy=false;self.refresh();return};self.snapshot=s;self.lastScanAt=Date()
        if s.files>0 {self.receiveCounter(s.total.total);UserDefaults.standard.set(NSNumber(value:s.total.total),forKey:self.displayTotalKey)}
        if self.tripBaseline==nil && s.files>0 {
            self.tripBaseline=(UserDefaults.standard.object(forKey:"trip:"+source.path) as? NSNumber)?.int64Value ?? s.total.total
            self.saveTrip()
        }
        if self.fuelBaseline==nil && s.files>0 {let migrated=UserDefaults.standard.string(forKey:"fuelVersion") != "0.10";let baseline=migrated ? s.total.total:((UserDefaults.standard.object(forKey:"fuel:"+source.path) as? NSNumber)?.int64Value ?? s.total.total);self.fuelBaseline=baseline;UserDefaults.standard.set(NSNumber(value:baseline),forKey:"fuel:"+source.path);UserDefaults.standard.set("0.10",forKey:"fuelVersion")}
        if !self.tripResetting {self.receiveTrip(self.trip);UserDefaults.standard.set(NSNumber(value:self.trip),forKey:self.displayTripKey)}
        self.busy=false}}}
    var rows:[SessionRow]{snapshot.sessions.filter{selection=="all" || $0.id==selection || "cwd:"+$0.cwd==selection}}
    var usage:Usage{rows.reduce(Usage()){$0+(today ? $1.today:$1.total)}}
    var rate:Int64{rows.reduce(0){$0+$1.rate}}
    var driveRate:Int64{selection=="all" ? snapshot.driveRate:rows.reduce(0){$0+$1.driveRate}}
    var activeWork:Int64 {max(0,snapshot.driveWork-(taskWorkBaseline ?? snapshot.driveWork))}
    var driveEffort:Double {
        let r=Double(driveRate)
        let rateScore:Double
        switch r {
        case ..<1_500: rateScore=r/7_500
        case ..<6_000: rateScore=0.20+(r-1_500)/18_000
        case ..<18_000: rateScore=0.45+(r-6_000)/40_000
        default: rateScore=min(1,0.75+(r-18_000)/68_000)
        }
        // Sustained new work, not cached context size, earns the upper gears.
        let progressScore=min(1,sqrt(Double(activeWork)/240_000))
        return min(1,max(rateScore,progressScore*0.85))
    }
    func choose(){let p=NSOpenPanel();p.canChooseDirectories=true;p.canChooseFiles=false;p.showsHiddenFiles=true;p.message="Select your Codex folder (.codex). Token Overdrive reads session logs only.";if p.runModal() == .OK,let url=p.url{if sourceAccessing {home.stopAccessingSecurityScopedResource()};sourceAccessing=url.startAccessingSecurityScopedResource();home=url;sourceAuthorized=sourceAccessing || FileManager.default.fileExists(atPath:url.path);tripBaseline=nil;counterReady=false;tripCounterReady=false;if let bookmark=try? url.bookmarkData(options:[.withSecurityScope,.securityScopeAllowOnlyReadAccess],includingResourceValuesForKeys:nil,relativeTo:nil){UserDefaults.standard.set(bookmark,forKey:"codexFolderBookmark")};preloadDisplays();refresh()}}
    func export(){let p=NSSavePanel();p.nameFieldStringValue="token-tacho.csv";if p.runModal() == .OK,let url=p.url{var csv="chat_id,eingabe,cache,ausgabe,gesamt\n";for r in rows{let u=today ? r.today:r.total;csv += "\(r.id),\(u.input),\(u.cache),\(u.output),\(u.total)\n"};do{try csv.write(to:url,atomically:true,encoding:.utf8)}catch{snapshot.error="Export fehlgeschlagen: \(error.localizedDescription)"}}}
}
let mint=Color(red:0.78,green:0.94,blue:0.53)
func number(_ n:Int64)->String{n.formatted(.number.locale(Locale(identifier:"de_DE")))}
func short(_ n:Int64)->String{if n>=1_000_000{return String(format:"%.1f M",Double(n)/1_000_000)};if n>=1000{return String(format:"%.1f k",Double(n)/1000)};return String(n)}
struct GaugeFace:View, Animatable {
    var value:Double
    var ceiling:Double
    var animatableData:Double {get{value}set{value=newValue}}
    var body:some View {
        Canvas{ctx,size in
            let c=CGPoint(x:size.width/2,y:size.height-70),r=min(size.width/2-24,size.height-86)
            let start=Double.pi*0.88,end=Double.pi*2.12,sweep=end-start
            var track=Path();track.addArc(center:c,radius:r,startAngle:.radians(start),endAngle:.radians(end),clockwise:false)
            ctx.stroke(track,with:.color(.white.opacity(0.10)),style:StrokeStyle(lineWidth:9,lineCap:.round))
            for i in 0...40 {
                let a=start+Double(i)/40*sweep,major=i%5==0
                let p=CGPoint(x:c.x+cos(a)*(r-10),y:c.y+sin(a)*(r-10))
                let q=CGPoint(x:c.x+cos(a)*(r-(major ? 24:16)),y:c.y+sin(a)*(r-(major ? 24:16)))
                var tick=Path();tick.move(to:p);tick.addLine(to:q)
                ctx.stroke(tick,with:.color(i>=35 ? .orange.opacity(0.8):.white.opacity(major ? 0.7:0.25)),lineWidth:major ? 2:1)
                if major {let label=CGPoint(x:c.x+cos(a)*(r-42),y:c.y+sin(a)*(r-42));ctx.draw(Text(short(Int64(ceiling*Double(i)/40))).foregroundColor(.secondary).font(.system(size:12)),at:label)}
            }
            let angle=start+min(max(value/ceiling,0),1)*sweep
            func point(_ distance:Double,_ side:Double)->CGPoint{CGPoint(x:c.x+cos(angle)*distance-sin(angle)*side,y:c.y+sin(angle)*distance+cos(angle)*side)}
            var needle=Path();needle.move(to:point(r-30,0));needle.addLine(to:point(-21,4));needle.addLine(to:point(-21,-4));needle.closeSubpath()
            ctx.fill(needle,with:.color(mint));ctx.fill(Path(ellipseIn:CGRect(x:c.x-12,y:c.y-12,width:24,height:24)),with:.color(Color(white:0.2)));ctx.fill(Path(ellipseIn:CGRect(x:c.x-5,y:c.y-5,width:10,height:10)),with:.color(mint))
        }.frame(height:240)
    }
}
struct Dial:View {
    let rate:Int64
    let ceiling:Double
    @Environment(\.accessibilityReduceMotion) var reducedMotion
    var body:some View {
        VStack(spacing:8){
            GaugeFace(value:Double(rate),ceiling:ceiling)
                .animation(reducedMotion ? nil:.interpolatingSpring(stiffness:45,damping:12),value:rate)
                .accessibilityLabel("\(rate) tokens per second, smoothed ten-second average")
            Text(number(rate)).font(.system(size:44,weight:.medium,design:.rounded)).monospacedDigit().foregroundStyle(mint)
            Text("Tokens / second").font(.callout)
            Text("Smoothed over 10 seconds · including cache").font(.caption).foregroundStyle(.secondary)
            if Double(rate)>ceiling {Text("Über Skalenmaximum · Zahlenwert bleibt vollständig").font(.caption).foregroundStyle(.orange)}
        }
    }
}
struct Dashboard:View {
    @ObservedObject var meter:Meter
    var body:some View {
        ScrollView {VStack(alignment:.leading,spacing:24){
            HStack{VStack(alignment:.leading){Text("TOKEN TACHO").font(.caption).tracking(3).foregroundStyle(mint);Text("Your usage. Live.").font(.title.bold())};Spacer();Label(meter.busy ? "Reading data …":"Connected locally",systemImage:"circle.fill").font(.caption).foregroundStyle(meter.snapshot.files>0 ? mint:.orange)}
            if meter.showDetails { HStack{Picker("View",selection:$meter.selection){Text("All local chats").tag("all");Section("Workspaces"){ForEach(Array(Set(meter.snapshot.sessions.map{$0.cwd})).filter{!$0.isEmpty}.sorted(),id:\.self){cwd in Text(URL(fileURLWithPath:cwd).lastPathComponent).tag("cwd:"+cwd)}};Section("Chats"){ForEach(meter.snapshot.sessions){r in Text(r.title).tag(r.id)}}}.frame(maxWidth:440);Spacer();Picker("Period",selection:$meter.today){Text("All time").tag(false);Text("Today").tag(true)}.pickerStyle(.segmented).labelsHidden().frame(width:160)} }
            HStack(alignment:.top,spacing:24){
                VStack(alignment:.leading){Text("Aktuelle Rate").font(.headline);Dial(rate:meter.rate,ceiling:meter.scale)}.padding(24).frame(maxWidth:.infinity).background(.white.opacity(0.04),in:RoundedRectangle(cornerRadius:22))
                VStack(alignment:.leading,spacing:18){Text(meter.today && meter.showDetails ? "Today":"Odometer").font(.headline);Text(number(meter.usage.total)).font(.system(size:32,weight:.medium,design:.monospaced)).minimumScaleFactor(0.5).lineLimit(1).foregroundStyle(mint).padding(.vertical,14);Text("Processed tokens including cache").font(.caption).foregroundStyle(.secondary);Divider();stat("New input",max(0,meter.usage.input-meter.usage.cache));stat("Cached input",meter.usage.cache);stat("Output including reasoning",meter.usage.output)}.padding(24).frame(maxWidth:.infinity,alignment:.leading).background(.white.opacity(0.04),in:RoundedRectangle(cornerRadius:22))
            }
            HStack{Label("Always on Top",systemImage:"pin");Toggle("Always on Top",isOn:$meter.floating).labelsHidden();Spacer();Button("Export CSV"){meter.export()}}
            if !meter.snapshot.error.isEmpty {Text(meter.snapshot.error).foregroundStyle(.orange).textSelection(.enabled)}
            if meter.snapshot.warnings>0 {Text("\(meter.snapshot.warnings) rückläufige oder ungültige Zählerstände wurden ausgelassen. Die Historie kann unvollständig sein.").font(.caption).foregroundStyle(.orange)}
            if meter.showDetails { Text("Zuletzt aktive Chats").font(.headline)
            ForEach(meter.rows.prefix(8)){r in HStack{VStack(alignment:.leading,spacing:3){Text(r.title).lineLimit(1);Text(r.latest?.formatted(date:.abbreviated,time:.shortened) ?? "No token events").font(.caption).foregroundStyle(.secondary)};Spacer();Text(number((meter.today ? r.today:r.total).total)).monospacedDigit();Button{meter.selection=r.id}label:{Image(systemName:"arrow.up.right")}.help("Show this chat")};Divider()}
            }
            HStack {Picker("Tacho-Skala",selection:$meter.scale){Text("8.000 / s").tag(8_000.0);Text("80.000 / s").tag(80_000.0);Text("800.000 / s").tag(800_000.0)}.frame(width:240);Spacer();Button(meter.showDetails ? "Details ausblenden":"Details anzeigen"){meter.showDetails.toggle();if !meter.showDetails {meter.selection="all";meter.today=false}}}
            VStack(alignment:.leading,spacing:6){Text("\(meter.snapshot.files) local logs · updated every two seconds");Text("No cloud billing, cost or subscription view. An event counts its processed context, not only newly written text. Missing or compressed logs are not reconstructed. The rate is based on bursty local log events, not second-by-second model metering.");Text(meter.home.path).textSelection(.enabled)}.font(.caption).foregroundStyle(.secondary)
        }.padding(28)}.frame(minWidth:740,minHeight:650).background(Color(red:0.055,green:0.08,blue:0.085)).preferredColorScheme(.dark)
    }
    func stat(_ label:String,_ n:Int64)->some View{HStack{Text(label).foregroundStyle(.secondary);Spacer();Text(number(n)).monospacedDigit()}.font(.callout)}
}
struct WindowSetup:NSViewRepresentable {
    func makeNSView(context:Context)->NSView {let v=NSView();DispatchQueue.main.async{v.window?.isMovableByWindowBackground=true;v.window?.backgroundColor = .white};return v}
    func updateNSView(_ nsView:NSView,context:Context){}
}
struct CarDial:View {
    let value:Double
    let maximum:Double
    let title:String
    let unit:String
    let odometerTitle:String
    let odometer:Int64
    let redStart:Double
    var body:some View {
        ZStack {
            Circle().fill(.white.opacity(0.76)).shadow(color:.black.opacity(0.08),radius:15,y:7)
            Circle().fill(RadialGradient(colors:[.white,Color(white:0.94)],center:.top,startRadius:1,endRadius:170)).padding(4)
            Circle().stroke(.black.opacity(0.08),lineWidth:0.7).padding(5)
            Circle().stroke(.black.opacity(0.04),lineWidth:0.7).padding(43)
            Canvas {ctx,size in
                let c=CGPoint(x:size.width/2,y:size.height/2),r=size.width/2-18,start=Double.pi*0.75,sweep=Double.pi*1.5
                var rail=Path();rail.addArc(center:c,radius:r,startAngle:.radians(start),endAngle:.radians(start+sweep),clockwise:false)
                ctx.stroke(rail,with:.color(.black.opacity(0.10)),style:StrokeStyle(lineWidth:5,lineCap:.round));ctx.stroke(rail,with:.color(.black.opacity(0.35)),lineWidth:1.3)
                var redZone=Path();redZone.addArc(center:c,radius:r-2,startAngle:.radians(start+redStart*sweep),endAngle:.radians(start+sweep),clockwise:false)
                let steps=maximum==9 ? 45:60
                for i in 0...steps {
                    let fraction=Double(i)/Double(steps),a=start+fraction*sweep,major=i%(maximum==9 ? 5:6)==0
                    var tick=Path();tick.move(to:CGPoint(x:c.x+cos(a)*(r-5),y:c.y+sin(a)*(r-5)));tick.addLine(to:CGPoint(x:c.x+cos(a)*(r-(major ? 20:9)),y:c.y+sin(a)*(r-(major ? 20:9))))
                    ctx.stroke(tick,with:.color(fraction>=redStart ? .red.opacity(0.75):.black.opacity(major ? 0.58:0.25)),lineWidth:major ? 1.4:0.6)
                    if major {let p=CGPoint(x:c.x+cos(a)*(r-34),y:c.y+sin(a)*(r-34));ctx.draw(Text("\(Int(maximum*fraction))").font(.custom("Dosis",size:maximum==9 ? 17:14)).foregroundColor(.black.opacity(0.72)),at:p)}
                }
            }
            VStack(spacing:3){Text(title).font(.custom("Dosis",size:10)).tracking(2);Text(unit).font(.custom("Dosis",size:9))}.foregroundStyle(.black.opacity(0.42)).offset(y:-27)
            GeometryReader { proxy in
                let s=proxy.size.width, c=s/2
                Path{p in p.move(to:CGPoint(x:c,y:27));p.addLine(to:CGPoint(x:c+3,y:c+12));p.addLine(to:CGPoint(x:c-3,y:c+12));p.closeSubpath()}.fill(Color(red:0.82,green:0.12,blue:0.10)).rotationEffect(.degrees(-135+min(1,max(0,value/maximum))*270),anchor:.init(x:0.5,y:0.5))
                Circle().fill(.black).frame(width:18,height:18).position(x:c,y:c).shadow(color:.black.opacity(0.18),radius:3,y:2)
            }.padding(0)
            VStack(spacing:2){Text(odometerTitle).font(.custom("Dosis",size:7.5)).tracking(0.5).foregroundStyle(.black.opacity(0.43));Text(number(odometer)).font(.custom("Dosis",size:15)).monospacedDigit().foregroundStyle(.black.opacity(0.82)).lineLimit(1).minimumScaleFactor(0.6)}.frame(width:145).padding(.vertical,5).offset(y:84)
        }.frame(width:250,height:250).accessibilityElement(children:.ignore).accessibilityLabel("\(title), \(Int(value)) \(unit), \(odometerTitle) \(odometer) Tokens")
    }
}
struct NightRoad:View {
    let distance:Double
    let bend:Double
    var body:some View {
        Canvas {ctx,size in
            let w=size.width,h=size.height,horizon=h*0.18,cell=max(2.0,round(w/92))
            func center(_ t:Double)->Double {w/2+bend*w*0.35*pow(1-t,2)+sin((distance+t)*0.9)*w*0.045*(1-t)}
            func y(_ t:Double)->Double {horizon+(h-horizon)*t}
            func half(_ t:Double)->Double {3+w*0.74*pow(t,1.45)}
            for row in 0..<Int(h/cell) {let yy=Double(row)*cell,t=min(1,max(0,(yy-horizon)/(h-horizon)));guard t>=0 else{continue};for col in 0..<Int(w/cell) {let xx=Double(col)*cell,inside=abs(xx-center(t))<half(t),pattern=sin(xx*0.08+Double(row)*0.43)+sin(xx*0.18-Double(row)*0.21),threshold=inside ? 0.92-t*0.18:1.30-t*0.62;if pattern>threshold {ctx.fill(Path(CGRect(x:xx,y:yy,width:cell-0.35,height:cell-0.35)),with:.color(inside ? .black.opacity(0.76):.black.opacity(0.26)))}}}
            let phase=(distance*0.9).truncatingRemainder(dividingBy:1)
            for i in 0..<11 {let raw=(Double(i)/11+phase).truncatingRemainder(dividingBy:1),t=pow(raw,1.5),p=CGPoint(x:center(t),y:y(t));ctx.fill(Path(CGRect(x:p.x-cell/2,y:p.y,width:cell,height:cell*1.5)),with:.color(.white.opacity(0.85)))}
            let p=CGPoint(x:center(0),y:horizon);ctx.fill(Path(ellipseIn:CGRect(x:p.x-2,y:p.y-2,width:4,height:4)),with:.color(.red.opacity(0.7)))
        }.clipped().accessibilityLabel("Simulierte Nachtstraße mit Kurven, gekoppelt an die Fahranimation")
    }
}
struct ResetButtonStyle:ButtonStyle {
    func makeBody(configuration:Configuration)->some View {
        configuration.label.font(.custom("Dosis",size:7.5)).tracking(0.8)
            .foregroundStyle(.white.opacity(0.94)).padding(.horizontal,8).padding(.vertical,5)
            .background(Capsule().fill(.black.opacity(configuration.isPressed ? 0.78:0.66)))
            .shadow(color:.black.opacity(0.12),radius:configuration.isPressed ? 0:2,y:1)
    }
}
struct MenuPillStyle:ButtonStyle {
    func makeBody(configuration:Configuration)->some View {configuration.label.padding(.horizontal,11).frame(height:28).foregroundStyle(.black.opacity(0.82)).background(.white.opacity(configuration.isPressed ? 0.78:0.54),in:RoundedRectangle(cornerRadius:8)).overlay(RoundedRectangle(cornerRadius:8).stroke(.black.opacity(0.07),lineWidth:1))}
}
struct TankDial:View {
    let load:Double
    let active:Bool
    var body:some View {ZStack {
        Circle().fill(.white.opacity(0.88)).shadow(color:.black.opacity(0.08),radius:8,y:4)
        Circle().stroke(.black.opacity(0.12),lineWidth:1).padding(7)
        Canvas {ctx,size in let c=CGPoint(x:size.width/2,y:size.height/2),r=size.width/2-14,start=Double.pi*0.78,sweep=Double.pi*1.44;var arc=Path();arc.addArc(center:c,radius:r,startAngle:.radians(start),endAngle:.radians(start+sweep),clockwise:false);ctx.stroke(arc,with:.color(.black.opacity(0.18)),style:StrokeStyle(lineWidth:4,lineCap:.round));var green=Path();green.addArc(center:c,radius:r,startAngle:.radians(start),endAngle:.radians(start+sweep*0.33),clockwise:false);ctx.stroke(green,with:.color(.green.opacity(0.65)),style:StrokeStyle(lineWidth:4,lineCap:.round));var red=Path();red.addArc(center:c,radius:r,startAngle:.radians(start+sweep*0.78),endAngle:.radians(start+sweep),clockwise:false);ctx.stroke(red,with:.color(.red.opacity(0.8)),style:StrokeStyle(lineWidth:4,lineCap:.round));let a=start+load*sweep;var needle=Path();needle.move(to:c);needle.addLine(to:CGPoint(x:c.x+cos(a)*(r-7),y:c.y+sin(a)*(r-7)));ctx.stroke(needle,with:.color(.black.opacity(0.75)),style:StrokeStyle(lineWidth:1.6,lineCap:.round));ctx.fill(Path(ellipseIn:CGRect(x:c.x-3,y:c.y-3,width:6,height:6)),with:.color(.black))}
        VStack(spacing:0){Text(active ? (load<0.33 ? "ECO" : load<0.78 ? "LOAD":"FULL") : "—").font(.custom("Dosis",size:12));Text("DRIVE").font(.custom("Dosis",size:6)).tracking(0.6)}.foregroundStyle(.black.opacity(0.64)).offset(y:9)
    }.frame(width:86,height:86).accessibilityLabel(active ? "Drive load" : "Drive standby")}
}
struct PauseFeedCard:View {
    let article:FeedArticle
    var body:some View {VStack(alignment:.leading,spacing:11){HStack{Text("RSS FEED").font(.custom("Dosis",size:8)).tracking(1.1).foregroundStyle(.black.opacity(0.42));Spacer()};Spacer(minLength:4);Text(article.title).font(.custom("Dosis",size:21)).lineSpacing(-1.5).foregroundStyle(.black.opacity(0.86)).lineLimit(5).minimumScaleFactor(0.76);Spacer(minLength:4);Text(article.subtitle).font(.custom("Dosis",size:9)).tracking(0.8).foregroundStyle(.black.opacity(0.48)).lineLimit(1)}.padding(17).frame(width:190,height:270,alignment:.leading).background(.white.opacity(0.84),in:RoundedRectangle(cornerRadius:19)).shadow(color:.black.opacity(0.10),radius:12,y:6).accessibilityLabel("RSS feed: \(article.title)").id(article.link).transition(.opacity).animation(.easeInOut(duration:0.32),value:article.link)}
}
struct PongCard:View {
    let onExit:()->Void
    @State private var ball=CGPoint(x:95,y:135)
    @State private var velocity=CGVector(dx:-2.1,dy:1.55)
    @State private var playerY:CGFloat=135
    @State private var aiY:CGFloat=135
    @State private var playerScore=0
    @State private var aiScore=0
    @State private var paddleTint: Color = .yellow
    @State private var timer:Timer?
    var body:some View {ZStack{
        RoundedRectangle(cornerRadius:19).fill(.black.opacity(0.93))
        Canvas {ctx,size in
            ctx.stroke(Path(CGRect(x:14,y:14,width:size.width-28,height:size.height-28)),with:.color(.white.opacity(0.22)),lineWidth:1)
            var mid=Path();mid.move(to:CGPoint(x:size.width/2,y:18));mid.addLine(to:CGPoint(x:size.width/2,y:size.height-18));ctx.stroke(mid,with:.color(.white.opacity(0.20)),style:StrokeStyle(lineWidth:1,dash:[3,4]))
            ctx.fill(Path(CGRect(x:18,y:clamp(playerY)-20,width:4,height:40)),with:.color(paddleTint))
            ctx.fill(Path(CGRect(x:size.width-22,y:clamp(aiY)-20,width:4,height:40)),with:.color(.white.opacity(0.72)))
            ctx.fill(Path(ellipseIn:CGRect(x:ball.x-3,y:ball.y-3,width:6,height:6)),with:.color(.white))
        }.onContinuousHover {phase in if case .active(let point)=phase {playerY=clamp(point.y)} }
        VStack{HStack{Text("PONG").tracking(1);Spacer();Text("\(playerScore) : \(aiScore)")}.font(.custom("Dosis",size:10)).foregroundStyle(.white.opacity(0.78)).padding(16);Spacer();Text("MOUSE MOVES YELLOW PADDLE").font(.custom("Dosis",size:7)).tracking(0.6).foregroundStyle(.white.opacity(0.42));Button("NEWS"){onExit()}.buttonStyle(.plain).font(.custom("Dosis",size:9)).tracking(0.8).foregroundStyle(.white.opacity(0.74)).padding(.top,7).padding(.bottom,14)}
    }.frame(width:190,height:270).onAppear{start()}.onDisappear{timer?.invalidate()}}
    func clamp(_ value:CGFloat)->CGFloat {max(35,min(235,value))}
    func start(){timer?.invalidate();timer=Timer.scheduledTimer(withTimeInterval:1.0/50,repeats:true){_ in step()}}
    func reset(towardPlayer:Bool){ball=CGPoint(x:95,y:135);velocity=CGVector(dx:towardPlayer ? -2.1:2.1,dy:Bool.random() ? 1.55:-1.55)}
    func step(){
        aiY += (ball.y-aiY)*0.075
        let next=CGPoint(x:ball.x+velocity.dx,y:ball.y+velocity.dy);var v=velocity
        if next.y<20 || next.y>250 {v.dy *= -1}
        if next.x<25 && v.dx<0 && abs(next.y-playerY)<25 {let accuracy=abs(next.y-playerY)/25;paddleTint=accuracy<0.24 ? .green : accuracy<0.58 ? .orange : .red;v.dx=abs(v.dx)*1.035;v.dy += (next.y-playerY)*0.045;playerScore += 1}
        if next.x>165 && v.dx>0 && abs(next.y-aiY)<25 {v.dx = -abs(v.dx)*1.025;v.dy += (next.y-aiY)*0.035}
        if next.x<8 {aiScore += 1;reset(towardPlayer:false);return}
        if next.x>182 {reset(towardPlayer:true);return}
        ball=next;velocity=v
    }
}
struct HandMark:View {
    let mark:String
    let color:Color
    @State private var progress=0.0
    var body:some View {Canvas {ctx,size in
        let inset:CGFloat=11
        if mark=="X" {var first=Path();first.move(to:CGPoint(x:inset,y:inset+2));first.addLine(to:CGPoint(x:size.width-inset,y:size.height-inset));var second=Path();second.move(to:CGPoint(x:size.width-inset,y:inset));second.addLine(to:CGPoint(x:inset,y:size.height-inset-2));ctx.stroke(first,with:.color(color.opacity(0.86)),style:StrokeStyle(lineWidth:3.5,lineCap:.round));ctx.stroke(second,with:.color(color.opacity(0.86)),style:StrokeStyle(lineWidth:3.5,lineCap:.round));ctx.stroke(first.trimmedPath(from:0,to:progress),with:.color(color),style:StrokeStyle(lineWidth:3.5,lineCap:.round));ctx.stroke(second.trimmedPath(from:0,to:progress),with:.color(color.opacity(0.96)),style:StrokeStyle(lineWidth:3.5,lineCap:.round))} else {var circle=Path();circle.addEllipse(in:CGRect(x:inset,y:inset,width:size.width-inset*2,height:size.height-inset*2));ctx.stroke(circle,with:.color(color.opacity(0.86)),style:StrokeStyle(lineWidth:3.3,lineCap:.round));ctx.stroke(circle.trimmedPath(from:0,to:progress),with:.color(color),style:StrokeStyle(lineWidth:3.3,lineCap:.round))}}
    .rotationEffect(.degrees(mark=="X" ? -4:7)).onAppear{withAnimation(.easeOut(duration:0.28)){progress=1}}}
}
struct TicTacToeCard:View {
    let onExit:()->Void
    @State private var cells=Array(repeating:"",count:9)
    @State private var playerSession=0
    @State private var computerSession=0
    @State private var didScore=false
    @State private var computerThinking=false
    @State private var restartCountdown:Int?=nil
    var winner:String? {let lines=[[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]];for line in lines {if !cells[line[0]].isEmpty && cells[line[0]]==cells[line[1]] && cells[line[1]]==cells[line[2]] {return cells[line[0]]}};return cells.allSatisfy{$0.isEmpty==false} ? "–":nil}
    var body:some View {VStack(spacing:0){VStack(spacing:10){HStack{Text("TIC-TAC-TOE").tracking(0.8);Spacer();Text(restartCountdown.map{"NEXT \($0)"} ?? "SESSION \(playerSession) : \(computerSession)")}.font(.custom("Dosis",size:9)).foregroundStyle(.white.opacity(0.82));LazyVGrid(columns:Array(repeating:GridItem(.fixed(46),spacing:4),count:3),spacing:4){ForEach(0..<9,id:\.self){index in Button{play(index)}label:{ZStack{RoundedRectangle(cornerRadius:5).fill(.white.opacity(0.10));if !cells[index].isEmpty {HandMark(mark:cells[index],color:cells[index]=="X" ? .yellow:.white)}}.frame(width:46,height:46)}.buttonStyle(.plain).disabled(!cells[index].isEmpty || winner != nil)}};Spacer();Button("NEWS"){onExit()}.buttonStyle(.plain).font(.custom("Dosis",size:9)).tracking(0.8).foregroundStyle(.white.opacity(0.74))}.padding(16)}.frame(width:190,height:270).background(.black.opacity(0.93),in:RoundedRectangle(cornerRadius:19))}
    func finishRound(){guard !didScore,let winner else{return};didScore=true;if winner=="X" {playerSession += 1}else if winner=="O" {computerSession += 1};restartCountdown=3;for second in 1...3 {DispatchQueue.main.asyncAfter(deadline:.now()+Double(second)){if second==3 {newRound()}else {restartCountdown=3-second}}}}
    func newRound(){cells=Array(repeating:"",count:9);didScore=false;computerThinking=false;restartCountdown=nil}
    func play(_ index:Int){guard cells[index].isEmpty,winner==nil,!computerThinking else{return};cells[index]="X";finishRound();guard winner==nil else{return};computerThinking=true;DispatchQueue.main.asyncAfter(deadline:.now()+0.65){guard winner==nil else{computerThinking=false;return};let choices=cells.indices.filter{cells[$0].isEmpty};if let move=choices.randomElement(){cells[move]="O"};computerThinking=false;finishRound()}}
}
struct SpaceHighScore:Codable,Identifiable {
    var name:String
    var score:Int
    var date:Date
    var id:String {"\(date.timeIntervalSince1970)-\(name)"}
}
struct SpaceEnemy:Identifiable {
    let id=UUID()
    var position:CGPoint
    var tier:Int
}
struct SpaceCard:View {
    let onExit:()->Void
    @State private var shipX:CGFloat=95
    @State private var enemies=[SpaceEnemy]()
    @State private var bullets=[CGPoint]()
    @State private var score=0
    @State private var frame=0
    @State private var gameOver=false
    @State private var entryName=""
    @State private var savedScore=false
    @State private var restartCountdown:Int?=nil
    @State private var timer:Timer?
    @State private var highScores:[SpaceHighScore]=[]
    var qualifies:Bool {highScores.count<5 || score>highScores.last?.score ?? 0}
    var body:some View {ZStack{
        RoundedRectangle(cornerRadius:19).fill(.black.opacity(0.94))
        Canvas {ctx,size in
            for x in stride(from:20,through:size.width-20,by:29) {for y in stride(from:28,through:size.height-30,by:37) {ctx.fill(Path(ellipseIn:CGRect(x:x,y:y,width:1,height:1)),with:.color(.white.opacity(0.20)))}}
            for enemy in enemies {let p=enemy.position;let tint:Color=enemy.tier==0 ? .white.opacity(0.72) : enemy.tier==1 ? .purple : .green.opacity(0.78);var ship=Path();if enemy.tier==0 {ship.move(to:CGPoint(x:p.x,y:p.y-7));ship.addLine(to:CGPoint(x:p.x-7,y:p.y-1));ship.addLine(to:CGPoint(x:p.x-4,y:p.y+5));ship.addLine(to:CGPoint(x:p.x,y:p.y+2));ship.addLine(to:CGPoint(x:p.x+4,y:p.y+5));ship.addLine(to:CGPoint(x:p.x+7,y:p.y-1))} else if enemy.tier==1 {ship.move(to:CGPoint(x:p.x,y:p.y-8));ship.addLine(to:CGPoint(x:p.x-8,y:p.y-3));ship.addLine(to:CGPoint(x:p.x-5,y:p.y+6));ship.addLine(to:CGPoint(x:p.x+5,y:p.y+6));ship.addLine(to:CGPoint(x:p.x+8,y:p.y-3))} else {ship.move(to:CGPoint(x:p.x,y:p.y-9));ship.addLine(to:CGPoint(x:p.x-9,y:p.y-2));ship.addLine(to:CGPoint(x:p.x-6,y:p.y+7));ship.addLine(to:CGPoint(x:p.x,y:p.y+3));ship.addLine(to:CGPoint(x:p.x+6,y:p.y+7));ship.addLine(to:CGPoint(x:p.x+9,y:p.y-2))};ship.closeSubpath();ctx.fill(ship,with:.color(tint));ctx.fill(Path(ellipseIn:CGRect(x:p.x-1.5,y:p.y-3,width:3,height:3)),with:.color(.black.opacity(0.72)))}
            for bullet in bullets {ctx.fill(Path(CGRect(x:bullet.x-1,y:bullet.y-5,width:2,height:7)),with:.color(.yellow))}
            let base=size.height-58;var player=Path();player.move(to:CGPoint(x:shipX,y:base-13));player.addLine(to:CGPoint(x:shipX-5,y:base-3));player.addLine(to:CGPoint(x:shipX-12,y:base+7));player.addLine(to:CGPoint(x:shipX-4,y:base+5));player.addLine(to:CGPoint(x:shipX,y:base+10));player.addLine(to:CGPoint(x:shipX+4,y:base+5));player.addLine(to:CGPoint(x:shipX+12,y:base+7));player.addLine(to:CGPoint(x:shipX+5,y:base-3));player.closeSubpath();ctx.fill(player,with:.color(.yellow));ctx.fill(Path(ellipseIn:CGRect(x:shipX-2,y:base-5,width:4,height:5)),with:.color(.black.opacity(0.72)))
        }.blur(radius:gameOver ? 4:0).onContinuousHover{phase in if case .active(let point)=phase {shipX=max(25,min(165,point.x))}}.onTapGesture{fire()}
        VStack{HStack{Text("STAR RUN").tracking(1);Spacer();Text("SCORE \(score)")}.font(.custom("Dosis",size:9)).foregroundStyle(.white.opacity(0.78)).padding(16);Spacer();if gameOver {gameOverPanel}else {Text("MOUSE MOVES · CLICK FIRES").font(.custom("Dosis",size:7)).tracking(0.5).foregroundStyle(.white.opacity(0.42));Button("NEWS"){onExit()}.buttonStyle(.plain).font(.custom("Dosis",size:9)).tracking(0.8).foregroundStyle(.white.opacity(0.74)).padding(.top,7).padding(.bottom,14)}}
    }.frame(width:190,height:270).onAppear{load();start()}.onDisappear{timer?.invalidate()}}
    var gameOverPanel:some View {VStack(spacing:7){Text(restartCountdown.map{"START \($0)"} ?? "GAME OVER").font(.custom("Dosis",size:13)).tracking(1).foregroundStyle(.yellow);if qualifies && !savedScore {HStack(spacing:6){TextField("NAME",text:$entryName).textFieldStyle(.plain).font(.custom("Dosis",size:10)).foregroundStyle(.black).padding(.horizontal,8).frame(width:76,height:25).background(.white,in:RoundedRectangle(cornerRadius:6));Button("SAVE"){save()}.buttonStyle(.plain).font(.custom("Dosis",size:9)).foregroundStyle(.black).padding(.horizontal,8).frame(height:25).background(.yellow,in:RoundedRectangle(cornerRadius:6))}} else if savedScore {Text("HIGH SCORE SAVED").font(.custom("Dosis",size:9)).tracking(0.6).foregroundStyle(.yellow)};VStack(spacing:3){ForEach(Array(highScores.prefix(5).enumerated()),id:\.element.id){index,item in HStack(spacing:4){Text("\(index+1). \(item.name.prefix(7))").frame(width:57,alignment:.leading);Text("\(item.score)").frame(width:34,alignment:.trailing);Spacer(minLength:0);Text(Self.dateText(item.date)).frame(width:31,alignment:.trailing)}.font(.custom("Dosis",size:10.5)).foregroundStyle(.white.opacity(0.82))}};if restartCountdown==nil {Button("NEWS"){onExit()}.buttonStyle(.plain).font(.custom("Dosis",size:8)).tracking(0.7).foregroundStyle(.white.opacity(0.60))}}.padding(.horizontal,12).padding(.vertical,10).background(.black.opacity(0.78),in:RoundedRectangle(cornerRadius:12)).padding(.horizontal,8).padding(.bottom,12)}
    func load(){if let data=UserDefaults.standard.data(forKey:"spaceHighScores"),let saved=try? JSONDecoder().decode([SpaceHighScore].self,from:data){highScores=saved.sorted{$0.score>$1.score}}}
    static func dateText(_ date:Date)->String {let formatter=DateFormatter();formatter.dateFormat="dd.MM";return formatter.string(from:date)}
    func save(){guard !savedScore else{return};let name=entryName.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ? "PILOT" : entryName.uppercased();highScores.append(SpaceHighScore(name:name,score:score,date:Date()));highScores=Array(highScores.sorted{$0.score>$1.score}.prefix(5));if let data=try? JSONEncoder().encode(highScores){UserDefaults.standard.set(data,forKey:"spaceHighScores")};entryName="";savedScore=true;scheduleRestart()}
    func fire(){guard !gameOver,bullets.count<3 else{return};bullets.append(CGPoint(x:shipX,y:196))}
    func start(){timer?.invalidate();timer=Timer.scheduledTimer(withTimeInterval:1.0/34,repeats:true){_ in step()}}
    func scheduleRestart(){restartCountdown=3;for second in 1...3 {DispatchQueue.main.asyncAfter(deadline:.now()+Double(second)){if second==3 {restart()}else {restartCountdown=3-second}}}}
    func restart(){enemies=[];bullets=[];score=0;frame=0;gameOver=false;entryName="";savedScore=false;restartCountdown=nil;start()}
    func step(){guard !gameOver else{return};frame += 1;let seconds=frame/34;let tier=seconds>=20 ? 2 : seconds>=10 ? 1 : 0;if frame%(tier==0 ? 30:24)==0 {enemies.append(SpaceEnemy(position:CGPoint(x:CGFloat(Int.random(in:25...165)),y:24),tier:tier))};enemies=enemies.map{enemy in var next=enemy;next.position.y += 1.25*(enemy.tier==0 ? 1:enemy.tier==1 ? 1.2:1.6);return next};bullets=bullets.map{CGPoint(x:$0.x,y:$0.y-4.2)}.filter{$0.y>17};var remaining=[SpaceEnemy]();for enemy in enemies {if enemy.position.y>225 {gameOver=true;timer?.invalidate();if !qualifies {scheduleRestart()};return};if let hit=bullets.firstIndex(where:{abs($0.x-enemy.position.x)<9 && abs($0.y-enemy.position.y)<11}) {bullets.remove(at:hit);score += enemy.tier==2 ? 30:enemy.tier==1 ? 20:10}else {remaining.append(enemy)}};enemies=remaining}
}
enum GalleryKind:String,CaseIterable,Identifiable {
    case california,beach,monsters
    var id:String {rawValue}
    var title:String {switch self {case .california:return "CALIFORNIA GIRLS";case .beach:return "BEACH BOYS";case .monsters:return "UGLY MONSTERS"}}
    var folder:String {switch self {case .california:return "CaliforniaGirls";case .beach:return "BeachBoys";case .monsters:return "UglyMonsters"}}
    var accent:Color {switch self {case .california:return .pink;case .beach:return .yellow;case .monsters:return .green}}
}
enum GalleryImages {
    static var cache=[String:NSImage]()
    static func image(_ kind:GalleryKind,_ index:Int)->NSImage? {let file=String(format:"%02d",index+1);let name="\(kind.folder)/\(file)";if let cached=cache[name]{return cached};guard let url=Bundle.main.url(forResource:file,withExtension:"png",subdirectory:"Gallery/\(kind.folder)"),let loaded=NSImage(contentsOf:url) else{return nil};cache[name]=loaded;return loaded}
    static func warm(){for kind in GalleryKind.allCases {for index in 0..<12 {_=image(kind,index)}}}
}
struct PixelGalleryCard:View {
    let onExit:()->Void
    let initialKind:GalleryKind
    @State private var kind:GalleryKind
    @State private var index=0
    @State private var timer:Timer?
    var image:NSImage? {GalleryImages.image(kind,index)}
    init(initialKind:GalleryKind,onExit:@escaping()->Void){self.initialKind=initialKind;self.onExit=onExit;_kind=State(initialValue:initialKind)}
    var body:some View {VStack(spacing:8){ZStack{
        Color(white:0.08)
        if let image {Image(nsImage:image).resizable().interpolation(.none).scaledToFit().frame(maxWidth:.infinity,maxHeight:.infinity).id("\(kind.rawValue)-\(index)").transition(.opacity)}
    }.frame(width:190,height:285).clipShape(RoundedRectangle(cornerRadius:19))
        HStack(spacing:6){ForEach(GalleryKind.allCases){choice in Button{choose(choice)}label:{Circle().fill(choice==kind ? choice.accent:.black.opacity(0.18)).frame(width:8,height:8)}.buttonStyle(.plain).accessibilityLabel(choice.title)}}
    }.onAppear{GalleryImages.warm();start()}.onDisappear{timer?.invalidate()}.animation(.easeInOut(duration:0.42),value:"\(kind.rawValue)-\(index)")}
    func start(){timer?.invalidate();timer=Timer.scheduledTimer(withTimeInterval:6.0,repeats:true){_ in next()}}
    func choose(_ choice:GalleryKind){guard choice != kind else{return};withAnimation(.easeInOut(duration:0.42)){kind=choice;index=0}}
    func next(){withAnimation(.easeInOut(duration:0.42)){index=(index+1)%12}}
}
struct TOBrandMark: View {
    var body: some View { ZStack {
        Circle().stroke(.black.opacity(0.88),lineWidth:4.6).frame(width:25,height:25).offset(x:7,y:2)
        Capsule().fill(.black.opacity(0.9)).frame(width:25,height:6).offset(x:-7,y:-6)
        Capsule().fill(.black.opacity(0.9)).frame(width:6,height:25).offset(x:-12,y:3)
        Capsule().fill(Color(red:0.91,green:0.16,blue:0.10)).frame(width:4.5,height:26).rotationEffect(.degrees(48),anchor:.bottom).offset(x:7,y:-3)
        Circle().fill(Color(red:0.91,green:0.16,blue:0.10)).frame(width:7,height:7).offset(x:3,y:4)
    }.frame(width:40,height:34) }
}
struct TokenOverdriveLockup: View {
    var body: some View {
        if let url=Bundle.main.url(forResource:"TokenOverdrive-Wordmark",withExtension:"svg"),let image=NSImage(contentsOf:url) {
            Image(nsImage:image).resizable().interpolation(.high).scaledToFit().frame(width:242,height:80,alignment:.leading)
        }
    }
}
struct SourceMenu:View {
    @ObservedObject var meter:Meter
    @Binding var details:Bool
    @Binding var preferences:Bool
    let onPong:()->Void
    let onTicTacToe:()->Void
    let onSpace:()->Void
    let onGallery:(GalleryKind)->Void
    let onRSS:()->Void
    let onSplash:()->Void
    @State private var page="sources"
    var body:some View {HStack(spacing:0){sidebar;Divider().overlay(.black.opacity(0.12));Group{if page=="sources" {sources} else if page=="games" {games} else if page=="gallery" {galleries} else if page=="legal" {legal} else {cockpit}}.frame(width:365,alignment:.topLeading).padding(20)}.frame(width:570,height:360).background(.white.opacity(0.58),in:RoundedRectangle(cornerRadius:22)).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:22)).shadow(color:.black.opacity(0.13),radius:26,y:12).preferredColorScheme(.light)}
    var sidebar:some View {VStack(alignment:.leading,spacing:5){menuButton("RSS FEEDS","dot.radiowaves.left.and.right","sources");menuButton("GAMES","gamecontroller","games");menuButton("GALLERY","photo.on.rectangle","gallery");Spacer();Divider().overlay(.black.opacity(0.12)).padding(.bottom,5);Button{page="cockpit"}label:{HStack(spacing:8){Image(systemName:"slider.horizontal.3");Text("TOKEN OVERDRIVE").font(.custom("Dosis",size:11)).fontWeight(.light).tracking(1.0)}.foregroundStyle(page=="cockpit" ? .black:.black.opacity(0.48)).padding(.horizontal,10).padding(.vertical,8).background(page=="cockpit" ? .white.opacity(0.62):.clear,in:RoundedRectangle(cornerRadius:9))}.buttonStyle(.plain);menuButton("PRIVACY & LEGAL","hand.raised","legal");Button{onSplash()}label:{HStack(spacing:6){Text("VERSION 0.9.7").font(.custom("Dosis",size:9)).fontWeight(.light).tracking(0.8);Spacer();Image(systemName:"play.fill").font(.system(size:7,weight:.medium))}.foregroundStyle(.black.opacity(0.44)).padding(.horizontal,10).padding(.vertical,5).contentShape(Rectangle())}.buttonStyle(.plain).accessibilityLabel("Show Token Overdrive splash screen")}.frame(width:142,alignment:.leading).padding(16)}
    func menuButton(_ title:String,_ icon:String,_ id:String)->some View {Button{page=id}label:{Label(title,systemImage:icon)}.buttonStyle(.plain).font(.custom("Dosis",size:14)).foregroundStyle(page==id ? .black:.black.opacity(0.48)).padding(.horizontal,10).padding(.vertical,8).background(page==id ? .white.opacity(0.62):.clear,in:RoundedRectangle(cornerRadius:9))}
    var sources:some View {VStack(alignment:.leading,spacing:8){ScrollView(.vertical,showsIndicators:false){VStack(spacing:5){ForEach(meter.feedPresets){preset in Button{meter.usePreset(preset);onRSS()}label:{HStack{Text(preset.name).font(.custom("Dosis",size:12)).tracking(0.6);Spacer();if meter.feedURL==preset.url {Image(systemName:"checkmark").font(.system(size:10,weight:.semibold))}}.padding(.horizontal,12).frame(height:30).background(.white.opacity(meter.feedURL==preset.url ? 0.80:0.36),in:RoundedRectangle(cornerRadius:9)).overlay(RoundedRectangle(cornerRadius:9).stroke(.black.opacity(meter.feedURL==preset.url ? 0.28:0.07),lineWidth:1))}.buttonStyle(.plain)}}}.frame(maxHeight:178);HStack(spacing:8){TextField("https:// RSS feed",text:$meter.feedDraft).textFieldStyle(.plain).font(.custom("Dosis",size:12)).padding(.horizontal,11).frame(height:32).background(.white.opacity(0.72),in:RoundedRectangle(cornerRadius:9));Button("CHECK"){meter.validateFeedDraft();onRSS()}.buttonStyle(.plain).font(.custom("Dosis",size:10)).tracking(0.7).foregroundStyle(.white).padding(.horizontal,14).frame(height:32).background(.black.opacity(0.80),in:RoundedRectangle(cornerRadius:9))};if !meter.feedValidation.isEmpty{Text(meter.feedValidation).font(.custom("Dosis",size:10)).foregroundStyle(.black.opacity(0.5)).lineLimit(1)}}}
    var games:some View {VStack(alignment:.leading,spacing:8){Button{onPong()}label:{HStack{Image(systemName:"circle.grid.cross");Text("PONG").font(.custom("Dosis",size:15)).tracking(1);Spacer();Image(systemName:"arrow.right")}.padding(11).background(.white.opacity(0.52),in:RoundedRectangle(cornerRadius:11))}.buttonStyle(.plain);Button{onTicTacToe()}label:{HStack{Image(systemName:"grid");Text("TIC-TAC-TOE").font(.custom("Dosis",size:13)).tracking(0.8);Spacer();Image(systemName:"arrow.right")}.padding(11).background(.white.opacity(0.38),in:RoundedRectangle(cornerRadius:11))}.buttonStyle(.plain);Button{onSpace()}label:{HStack{Image(systemName:"paperplane");Text("STAR RUN").font(.custom("Dosis",size:13)).tracking(0.8);Spacer();Image(systemName:"arrow.right")}.padding(11).background(.white.opacity(0.38),in:RoundedRectangle(cornerRadius:11))}.buttonStyle(.plain);Spacer()}}
    var galleries:some View {VStack(alignment:.leading,spacing:8){ForEach(GalleryKind.allCases){kind in Button{onGallery(kind)}label:{HStack{Circle().fill(kind.accent).frame(width:10,height:10);Text(kind.title).font(.custom("Dosis",size:13)).tracking(0.7);Spacer()}.padding(11).background(.white.opacity(0.46),in:RoundedRectangle(cornerRadius:11))}.buttonStyle(.plain)};Spacer()}}
    var cockpit:some View {VStack(alignment:.leading,spacing:10){TokenOverdriveLockup().padding(.top,2);Divider().overlay(.black.opacity(0.12));VStack(alignment:.leading,spacing:10){Toggle("Always on Top",isOn:$meter.floating);HStack(spacing:8){Button("Dock Top"){meter.dock(top:true)}.buttonStyle(MenuPillStyle());Button("Dock Bottom"){meter.dock(top:false)}.buttonStyle(MenuPillStyle())};Toggle("Engine Sound",isOn:$meter.soundOn);VStack(alignment:.leading,spacing:4){Text("VOLUME").font(.custom("Dosis",size:8)).tracking(0.8).foregroundStyle(.black.opacity(0.48));Slider(value:$meter.volume,in:0...0.3)};Text(meter.micStatus).font(.custom("Dosis",size:8)).tracking(0.45).foregroundStyle(meter.micOn ? .black.opacity(0.62):.black.opacity(0.38));VStack(alignment:.leading,spacing:3){Text(meter.localSourceStatus).font(.custom("Dosis",size:9)).tracking(0.45).foregroundStyle(meter.snapshot.files>0 ? .black.opacity(0.72):.red.opacity(0.72)).lineLimit(1);Text(meter.localSourceHint).font(.custom("Dosis",size:8)).foregroundStyle(.black.opacity(0.44)).lineLimit(1)}.padding(8).frame(maxWidth:.infinity,alignment:.leading).background(.black.opacity(0.045),in:RoundedRectangle(cornerRadius:8));VStack(alignment:.leading,spacing:2){Text("CHATGPT ACCOUNT · OPTIONAL").font(.custom("Dosis",size:9)).tracking(0.45).foregroundStyle(.black.opacity(0.65));Text("You will always be asked before account activity is connected. Chat content is never read or stored.").font(.custom("Dosis",size:8)).foregroundStyle(.black.opacity(0.44)).lineLimit(2)}.padding(8).frame(maxWidth:.infinity,alignment:.leading).background(.black.opacity(0.028),in:RoundedRectangle(cornerRadius:8));HStack{Button("Codex Folder"){meter.choose()}.buttonStyle(MenuPillStyle());Button("Check Source"){meter.refresh()}.buttonStyle(MenuPillStyle());Button(meter.micOn ? "Disable Microphone":"Enable Microphone"){meter.toggleMic()}.buttonStyle(MenuPillStyle());Spacer();Button("Quit"){NSApp.terminate(nil)}.buttonStyle(MenuPillStyle())}}.padding(.top,2);Spacer()}.font(.custom("Dosis",size:12)).tint(Color(white:0.23))}
    var legal:some View {VStack(alignment:.leading,spacing:9){TokenOverdriveLockup().padding(.top,2);Text("VERSION 0.9.7 · © 2026 OLLIFOLIO").font(.custom("Dosis",size:10)).tracking(0.7).foregroundStyle(.black.opacity(0.52));Divider().overlay(.black.opacity(0.12));Text("Local-first. No accounts, analytics, advertising or cloud token tracking. Codex logs stay on this Mac. Microphone level is optional and never recorded. RSS sources load only after you choose them.").font(.custom("Dosis",size:11)).foregroundStyle(.black.opacity(0.72)).fixedSize(horizontal:false,vertical:true);HStack(spacing:13){Link("Privacy Policy",destination:URL(string:"https://ollifolio.com/apps/to/privacy")!);Link("Imprint",destination:URL(string:"https://ollifolio.com/apps/to/imprint")!);Link("Support",destination:URL(string:"https://ollifolio.com/apps/to")!)}.font(.custom("Dosis",size:11)).foregroundStyle(.black);Spacer()}.font(.custom("Dosis",size:12))}
}
struct Cockpit:View {
    @ObservedObject var meter:Meter
    @State var details=false
    @State var preferences=false
    @State var pong=false
    @State var ticTacToe=false
    @State var space=false
    @State var gallery:GalleryKind?=nil
    @State private var versionSheet=false
    var center:some View {ZStack(alignment:.top){if pong {PongCard{pong=false}} else if ticTacToe {TicTacToeCard{ticTacToe=false}} else if space {SpaceCard{space=false}} else if let gallery {PixelGalleryCard(initialKind:gallery){self.gallery=nil}} else {VStack(spacing:12){PauseFeedCard(article:meter.feed);if !meter.feedItems.isEmpty{HStack(spacing:12){Button{meter.previousFeed()}label:{Image(systemName:"chevron.left")}.disabled(meter.feedHistory.isEmpty).buttonStyle(.plain);Text("\(meter.feedIndex+1) / \(meter.feedItems.count)").font(.custom("Dosis",size:9));Button{meter.advanceFeed()}label:{Image(systemName:"chevron.right")}.disabled(meter.feedItems.count<2).buttonStyle(.plain)}}}.offset(y:-16).zIndex(2)}}.frame(width:190,height:302,alignment:.top)}
    func randomize(){pong=false;ticTacToe=false;space=false;gallery=nil;switch Int.random(in:0...5) {case 0:if !meter.feedItems.isEmpty {meter.showFeed(Int.random(in:0..<meter.feedItems.count),direction:1)};case 1:gallery=GalleryKind.allCases.randomElement() ?? .california;case 2:pong=true;case 3:ticTacToe=true;case 4:space=true;default:if !meter.feedItems.isEmpty {meter.showFeed(Int.random(in:0..<meter.feedItems.count),direction:1)}}}
    var randomButton:some View {Button{randomize()}label:{ZStack{RoundedRectangle(cornerRadius:8).fill(LinearGradient(colors:[.white,Color(white:0.93)],startPoint:.top,endPoint:.bottom));RoundedRectangle(cornerRadius:8).stroke(.black.opacity(0.06),lineWidth:1);Text("R").font(.custom("Dosis",size:12)).fontWeight(.medium).foregroundStyle(.black.opacity(0.82)).offset(y:-0.4)}.frame(width:29,height:29).shadow(color:.black.opacity(0.10),radius:5,y:2.5).shadow(color:.white.opacity(0.95),radius:1,y:-1)}.buttonStyle(.plain).accessibilityLabel("Show something random")}
    var cockpit:some View {ZStack(alignment:.topLeading){VStack(spacing:0){HStack{Spacer()}.frame(height:56).padding(.trailing,60);HStack(spacing:11){CarDial(value:meter.rpm/1000,maximum:9,title:"ENGINE",unit:"× 1.000 RPM",odometerTitle:"TOKENS + CACHE",odometer:meter.visibleTotal,redStart:0.77);center;VStack(spacing:-12){ZStack(alignment:.topLeading){CarDial(value:meter.speedNeedle,maximum:300,title:"SPEED",unit:"",odometerTitle:"TRIP TOKENS",odometer:meter.visibleTrip,redStart:0.85);TankDial(load:meter.loadNeedle,active:meter.snapshot.active).offset(x:177,y:-13)};Button("TRIP RESET"){meter.resetTrip()}.disabled(meter.snapshot.files==0 || meter.tripResetting).buttonStyle(ResetButtonStyle())}}.frame(maxWidth:.infinity);HStack(spacing:12){Button{meter.toggleMic()}label:{Image(systemName:meter.micOn ? "mic.fill":"mic.slash")}.foregroundStyle(meter.micOn ? .black:.gray);Button{meter.soundOn.toggle()}label:{Image(systemName:meter.soundOn ? "speaker.wave.2.fill":"speaker.slash")}.foregroundStyle(meter.soundOn ? .black:.gray);Spacer()}.buttonStyle(.plain).font(.system(size:10,weight:.medium)).padding(.horizontal,21).padding(.bottom,8)}.offset(y:-9);Button{preferences=true}label:{ZStack(alignment:.topLeading){Color.clear;Image(systemName:"ellipsis").font(.system(size:18,weight:.bold)).foregroundStyle(.black.opacity(0.5)).frame(width:24,height:24).offset(x:27,y:4)}.frame(width:96,height:82).contentShape(Rectangle())}.buttonStyle(.plain).position(x:48,y:41);randomButton.position(x:518,y:45)}
    }
    var body:some View {ZStack{cockpit;if preferences {Color.white.opacity(0.20).background(.ultraThinMaterial).contentShape(Rectangle()).onTapGesture{preferences=false};SourceMenu(meter:meter,details:$details,preferences:$preferences,onPong:{pong=true;ticTacToe=false;space=false;gallery=nil;preferences=false},onTicTacToe:{ticTacToe=true;pong=false;space=false;gallery=nil;preferences=false},onSpace:{space=true;pong=false;ticTacToe=false;gallery=nil;preferences=false},onGallery:{kind in gallery=kind;pong=false;ticTacToe=false;space=false;preferences=false},onRSS:{pong=false;ticTacToe=false;space=false;gallery=nil;preferences=false},onSplash:{preferences=false;DispatchQueue.main.asyncAfter(deadline:.now()+0.16){versionSheet=true}}).offset(y:-16).transition(.opacity.combined(with:.scale(scale:0.96)))}}.frame(width:800,height:390).background(LinearGradient(colors:[.white,Color(white:0.965)],startPoint:.top,endPoint:.bottom)).foregroundStyle(.black).background(WindowSetup()).animation(.easeInOut(duration:0.18),value:preferences).onExitCommand{if preferences {preferences=false}else if pong {pong=false}else if ticTacToe {ticTacToe=false}else if space {space=false}else if gallery != nil {gallery=nil}}.sheet(isPresented:$details){Dashboard(meter:meter).frame(width:850,height:750).toolbar{Button("Close"){details=false}}}.sheet(isPresented:$versionSheet){VersionReplaySheet(presented:$versionSheet)}}
}
struct MenuContent:View{@ObservedObject var meter:Meter;var body:some View{Text("Token Overdrive").font(.headline);Text("\(number(meter.rate)) tokens / second");Text("Today: \(number(meter.snapshot.today.total)) tokens");Divider();Button("Open Window"){NSApp.activate(ignoringOtherApps:true);NSApp.windows.first(where:{$0.title=="Token Overdrive"})?.makeKeyAndOrderFront(nil)};Button("Quit"){NSApp.terminate(nil)}}}
struct LaunchSplash: View {
    private let artwork = NSImage(contentsOf: Bundle.main.url(forResource:"TokenOverdriveSplash",withExtension:"png",subdirectory:"Splash") ?? URL(fileURLWithPath:"/dev/null"))
    var body: some View { ZStack(alignment:.bottomTrailing) {
        Color(white:0.98)
        if let artwork { Image(nsImage:artwork).resizable().interpolation(.high).scaledToFit().frame(maxWidth:.infinity,maxHeight:.infinity) }
        Text("VERSION 0.9.7").font(.custom("Dosis",size:10)).fontWeight(.light).tracking(1.4).foregroundStyle(.black.opacity(0.54)).padding(.trailing,18).padding(.bottom,15)
    }.frame(width:800,height:390).background(WindowSetup()) }
}
struct VersionReplaySheet: View {
    @Binding var presented: Bool
    @State private var opacity=0.0
    var body: some View { LaunchSplash().opacity(opacity).onAppear { withAnimation(.easeIn(duration:0.22)){opacity=1};DispatchQueue.main.asyncAfter(deadline:.now()+3){withAnimation(.easeOut(duration:0.25)){opacity=0};DispatchQueue.main.asyncAfter(deadline:.now()+0.27){presented=false}} }.interactiveDismissDisabled() }
}
struct ChatGPTConnectionNotice: View {
    let dismiss:()->Void
    var body: some View { VStack(alignment:.leading,spacing:14){Text("CONNECT CHATGPT").font(.custom("Dosis",size:17)).tracking(1.0);Text("Token Overdrive is preparing an optional connection for account-level token activity.").font(.custom("Dosis",size:14)).fixedSize(horizontal:false,vertical:true);Text("You will always be asked before anything is connected. Your chats, prompts and responses are never read or stored.").font(.custom("Dosis",size:12)).foregroundStyle(.black.opacity(0.56)).fixedSize(horizontal:false,vertical:true);HStack{Spacer();Button("GOT IT"){dismiss()}.buttonStyle(MenuPillStyle())}}.padding(22).frame(width:360).background(.white,in:RoundedRectangle(cornerRadius:18)).shadow(color:.black.opacity(0.16),radius:26,y:12) }
}
struct LaunchGate: View {
    @ObservedObject var meter: Meter
    @State private var showSplash = true
    @AppStorage("chatGPTConnectionNoticeSeen") private var chatGPTConnectionNoticeSeen=false
    @State private var showConnectionNotice=false
    var body: some View { ZStack { Cockpit(meter:meter).opacity(showSplash ? 0 : 1); if showSplash { LaunchSplash().transition(.opacity) };if showConnectionNotice {Color.black.opacity(0.12).ignoresSafeArea();ChatGPTConnectionNotice{chatGPTConnectionNoticeSeen=true;withAnimation(.easeOut(duration:0.18)){showConnectionNotice=false}}.transition(.opacity.combined(with:.scale(scale:0.96))) } }.task { try? await Task.sleep(for:.seconds(1)); withAnimation(.easeOut(duration:0.18)){showSplash=false};guard !chatGPTConnectionNoticeSeen else{return};try? await Task.sleep(for:.milliseconds(300));withAnimation(.easeOut(duration:0.18)){showConnectionNotice=true} } }
}
struct TachoApp:App {
    @StateObject var meter=Meter()
    init(){AppFont.register()}
    var body:some Scene {
        WindowGroup("Token Overdrive"){LaunchGate(meter:meter)}.windowStyle(.hiddenTitleBar).windowResizability(.contentSize).defaultSize(width:800,height:390)
        MenuBarExtra {MenuContent(meter:meter)} label:{Label("\(short(meter.rate))/s",systemImage:"speedometer")}
    }
}
func selfTest(){
    let feedSample="""
    <rss><channel><item><title><![CDATA[Ein guter Test]]></title><link>https://tracker.invalid/x</link><description><![CDATA[<a href="https://www.der-postillon.com/test.html"><img src="https://blogger.googleusercontent.com/test.jpg"></a>]]></description></item></channel></rss>
    """
    let parsedFeed=FeedArticle.parse(feedSample)!;precondition(parsedFeed.title=="Ein guter Test" && parsedFeed.link?.host=="www.der-postillon.com" && parsedFeed.image != nil)
    func event(_ n:Int64,_ cached:Int64=0)->[String:Any]{["type":"event_msg","timestamp":"2026-10-27T10:00:00Z","payload":["type":"token_count","info":["total_token_usage":["input_tokens":n,"cached_input_tokens":cached,"output_tokens":n/10]]]]}
    let activity=Session("activity")
    activity.consume(["type":"event_msg","timestamp":"2026-10-27T10:00:00Z","payload":["type":"task_started"]])
    precondition(activity.activeAt != nil)
    activity.consume(["type":"event_msg","timestamp":"2026-10-27T10:01:00Z","payload":["type":"task_complete"]])
    precondition(activity.activeAt == nil)
    let s=Session("test");s.consume(event(100,50));s.consume(event(100,50));s.consume(event(200,150));s.consume(event(100,50));s.consume(event(300,200));precondition(s.ticks.reduce(0){$0+$1.usage.total}==330);precondition(s.ticks.reduce(0){$0+$1.usage.cache}==200);precondition(s.warnings==1)
    let f=Session("fork");f.consume(["type":"session_meta","payload":["id":"fork","forked_from_id":"parent"]]);f.consume(event(100));f.consume(event(200));precondition(f.ticks.reduce(0){$0+$1.usage.total}==110)
    let dir=FileManager.default.temporaryDirectory.appendingPathComponent("token-tacho-test-"+UUID().uuidString)
    try! FileManager.default.createDirectory(at:dir.appendingPathComponent("sessions"),withIntermediateDirectories:true)
    defer {try? FileManager.default.removeItem(at:dir)}
    let url=dir.appendingPathComponent("sessions/test.jsonl")
    func line(_ o:[String:Any])->Data {var d=try! JSONSerialization.data(withJSONObject:o);d.append(10);return d}
    try! line(event(100,50)).write(to:url)
    let tail=Tail(url);try! tail.read();try! tail.read();precondition(tail.session.ticks.count==1)
    let next=line(event(200,150)),half=next.count/2
    let h=try! FileHandle(forWritingTo:url);try! h.seekToEnd();try! h.write(contentsOf:next.prefix(half));try! tail.read();precondition(tail.session.ticks.count==1)
    try! h.write(contentsOf:next.suffix(next.count-half));try! h.close();try! tail.read();precondition(tail.session.ticks.count==2)
    let fresh=Tail(url);try! fresh.read();precondition(fresh.session.ticks.reduce(0){$0+$1.usage.total}==220)
    try! line(event(50)).write(to:url);try! tail.read();precondition(tail.session.ticks.reduce(0){$0+$1.usage.total}==55)
    MainActor.assumeIsolated {
        let meter=Meter(start:false)
        meter.bendsEnabled=false
        meter.snapshot.active=true
        var previousRPM=0.0,previousGear=1,shiftDrop=false
        let origin=Date()
        for frame in 0..<900 {
            meter.stepNeedle(now:origin.addingTimeInterval(Double(frame)/30))
            if meter.gear>previousGear && meter.rpm<previousRPM {shiftDrop=true}
            previousRPM=meter.rpm;previousGear=meter.gear
        }
        precondition(meter.speed>60 && meter.speed<=300)
        precondition(meter.gear>=2 && shiftDrop)
        precondition(meter.rpm>1_500 && meter.rpm<4_000)
        meter.snapshot.active=false
        for frame in 0..<900 {meter.stepNeedle(now:origin.addingTimeInterval(30+Double(frame)/30))}
        precondition(meter.speed<0.1 && meter.rpm<100)
        meter.snapshot.driveRate=500;meter.snapshot.driveWork=0;meter.taskWorkBaseline=0;precondition(meter.driveEffort<0.1)
        meter.snapshot.driveRate=20_000;meter.snapshot.driveWork=240_000;precondition(meter.driveEffort>=0.84 && meter.driveEffort<1)
        meter.snapshot.driveRate=0;meter.snapshot.driveWork=0;meter.taskWorkBaseline=nil
        meter.snapshot.total=Usage(input:1000,cache:500,output:100)
        meter.tripBaseline=1000;precondition(meter.trip==100)
        meter.tripBaseline=1100;precondition(meter.trip==0 && meter.snapshot.total.total==1100)
        meter.receiveCounter(1100,now:origin)
        meter.receiveCounter(2200,now:origin)
        meter.animateCounter(now:origin.addingTimeInterval(1.2));precondition(meter.visibleTotal>1100 && meter.visibleTotal<2200)
        meter.animateCounter(now:origin.addingTimeInterval(3));precondition(meter.visibleTotal==2200)
        meter.receiveCounter(2600,now:origin.addingTimeInterval(4));meter.animateCounter(now:origin.addingTimeInterval(4.4));let firstRoll=meter.visibleTotal;meter.receiveCounter(3200,now:origin.addingTimeInterval(4.5));meter.animateCounter(now:origin.addingTimeInterval(5));precondition(meter.visibleTotal>firstRoll && meter.visibleTotal<3200);meter.animateCounter(now:origin.addingTimeInterval(7));precondition(meter.visibleTotal==3200)
        // TRIP has the same incremental animation and exact settling semantics as TOTAL.
        meter.tripDisplayed=0;meter.tripCounterTarget=0;meter.tripCounterReady=true;meter.tripCounterLastFrame=origin
        meter.receiveTrip(1_100,now:origin);meter.animateTrip(now:origin.addingTimeInterval(1.2));precondition(meter.visibleTrip>0 && meter.visibleTrip<1_100)
        meter.animateTrip(now:origin.addingTimeInterval(3));precondition(meter.visibleTrip==1_100)
        meter.receiveTrip(2_600,now:origin.addingTimeInterval(4));meter.animateTrip(now:origin.addingTimeInterval(4.4));let firstTripRoll=meter.visibleTrip
        meter.receiveTrip(3_200,now:origin.addingTimeInterval(4.5));meter.animateTrip(now:origin.addingTimeInterval(5));precondition(meter.visibleTrip>firstTripRoll && meter.visibleTrip<3_200)
        meter.animateTrip(now:origin.addingTimeInterval(7));precondition(meter.visibleTrip==3_200)
        meter.receiveCounter(10_000,now:origin.addingTimeInterval(8));meter.animateCounter(now:origin.addingTimeInterval(11));meter.tripDisplayed=0;meter.tripCounterTarget=0;meter.tripCounterReady=true;meter.snapshot.active=true;meter.rpm=3_000;meter.stepNeedle(now:origin.addingTimeInterval(12));meter.stepNeedle(now:origin.addingTimeInterval(13));precondition(meter.visibleTotal>10_000 && meter.visibleTrip>0);meter.snapshot.active=false;meter.stepNeedle(now:origin.addingTimeInterval(16));precondition(meter.visibleTotal==10_000 && meter.visibleTrip==0)
        meter.bendsEnabled=true;meter.snapshot.active=true
        var low=300.0,high=0.0
        for frame in 0..<3600 {meter.stepNeedle(now:origin.addingTimeInterval(60+Double(frame)/30));if frame>600{low=min(low,meter.speed);high=max(high,meter.speed)}}
        precondition(high-low>5 && meter.speed<=300 && meter.rpm<9000)
    }
    print("PASS: mirrored TOTAL/TRIP animation, exact counter settling, curve dynamics, driving, shift drop, coasting, TRIP isolation, task start/stop, cumulative deltas, duplicates, stale snapshots, cache inclusion, fork baseline, partial lines, incremental read, restart, truncation")
}
func feedDiagnose(){
    func get(_ url:URL)->(Data?,URLResponse?){let gate=DispatchSemaphore(value:0);var result:(Data?,URLResponse?)=(nil,nil);var request=URLRequest(url:url);request.timeoutInterval=20;request.setValue("Token Drive RSS Reader/1.0",forHTTPHeaderField:"User-Agent");URLSession.shared.dataTask(with:request){data,response,_ in result=(data,response);gate.signal()}.resume();_ = gate.wait(timeout:.now()+25);return result}
    let feedURL=URL(string:"https://www.der-postillon.com/feeds/posts/default?alt=rss&max-results=1")!;let (feedData,_)=get(feedURL);guard let feedData,let xml=String(data:feedData,encoding:.utf8) else{print("FEED: failed");return};let articles=FeedArticle.parseAll(xml);print("FEED: articles=\(articles.count) images=\(articles.filter{$0.image != nil}.count)");guard let imageURL=articles.first?.image else{return};let (imageData,response)=get(imageURL);let status=(response as? HTTPURLResponse)?.statusCode ?? -1;print("IMAGE: status=\(status) bytes=\(imageData?.count ?? 0) decoded=\(imageData.flatMap(NSImage.init(data:)) != nil)")
}
if CommandLine.arguments.contains("--self-test"){selfTest()}else if CommandLine.arguments.contains("--feed-diagnose"){feedDiagnose()}else if CommandLine.arguments.contains("--diagnose") {let s=Reader().scan(home:FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex"));print("files=\(s.files) sessions=\(s.sessions.count) total=\(s.total.total) cache=\(s.total.cache) warnings=\(s.warnings) error=\(s.error)")}else if CommandLine.arguments.contains("--render") {
    MainActor.assumeIsolated {
    let app=NSApplication.shared
    let m=Meter(start:false);m.snapshot=Reader().scan(home:m.home);m.tripBaseline=max(0,m.snapshot.total.total-125000);m.receiveCounter(m.snapshot.total.total);m.roadDistance=1.2;m.speed=90;m.rpm=4800;m.gear=3;m.needle=m.rpm/9000
    let view=NSHostingView(rootView:Cockpit(meter:m));view.frame=NSRect(x:0,y:0,width:940,height:440)
    view.layoutSubtreeIfNeeded()
    if let rep=view.bitmapImageRepForCachingDisplay(in:view.bounds){view.cacheDisplay(in:view.bounds,to:rep);if let data=rep.representation(using:.png,properties:[:]) {try! data.write(to:URL(fileURLWithPath:CommandLine.arguments.last!));print("Preview rendered")}}
    _ = app
    }
}else{TachoApp.main()}
