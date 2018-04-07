
videomode$="1920x1080x50p"
v=CreateObject("roVideoPlayer")
vmode = createobject("roVideoMode")
vmode.SetMode(videomode$)

v.SetLoopMode(true)
list=matchfiles(".","*.mp4")
v.PlayFile(list.RemoveHead())

while true
sleep(1000)
end while