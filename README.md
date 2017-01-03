# Playmat

Playmat is a graphics library for use with the [LÖVE Lua Framework](https://love2d.org/).
It does the popular SNES Mode7 effect used in games such as Super Mario Kart and F-Zero.

**Features**
+ Super easy to set-up.
+ Built-in flexible sprite system.
+ Multiple plane support.
+ Helper functions.
+ Runs on slow computers.

To get started, just copy the ```playmat.lua``` file to your project and require it in your code like this:
```lua
playmat = require "playmat.lua"
```

### Documentation

```lua
camera = playmat.newCamera( w,h, x,y, r, zoom, fov, offset )
```
Returns a camera object, which is used to store settings for this library's main drawing functions.
-
number w (800)
	The width of the view window (in pixels) that it will render at.
number h (600)
	The height of the view window (in pixels) that it will render at.
number x (0)
	The x position of the camera, in texture coordinates.
number y (0)
	The y position of the camera, in texture coordinates.
number r (0)
	The rotation of the camera (in radians)
number zoom (32)
	The camera zoom.
number fov (1.0)
	The camera's relative y-scale, it stretches based on the percentage. (e.g. 2.0 is twice as far, 0.5 is half.)
number offset (1.0)
	The camera's center offset, it changes where the center is rendered. (0.5 is the middle of the view port, 2.0 is twice below.)


```lua
camera = playmat.drawPlane( image, camera, ox,oy, x,y,w,h)
```
Draws a Mode7 style plane with the camera object.
-
Drawable image
The image to use.
Camera camera
	The camera to draw it from.
number ox (0)
	The x position of where the plane will draw.
number oy (0)
	The y position of where the plane will draw.
number x (0)
	The x offset of the view window that it will render to.
number y (0)
	The y offset of the view window that it will render to.
number w (0)
	The width of the view window that it will render to.
number h (0)
	The height of the view window that it will render to.
	
```lua
camera = playmat.putSprite( camera, image, x,y, r, sx,sy, ...)
```
Buffers a sprite to draw.
-


##Credits:

Retrotails - Original shader code.
Hatninja - The library.

As of now, most of the library is subject to change.
Feedback & Criticism would be very much appreciated!