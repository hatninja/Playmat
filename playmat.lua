-- Copyright (c) 2017 Hatninja
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

--Playmat Library v1.0.2
local PM = {}

local tau,cos,sin,min, insert,remove,sort = math.pi*2,math.cos,math.sin,math.min, table.insert,table.remove,table.sort
local lg = love.graphics

local shader = lg.newShader [[
extern Image map;
extern number x = 0;
extern number y = 0;
extern number zoomx = 32;
extern number zoomy = 32;
extern number fov = 1.0;
extern number offset = 1.0;
extern int wrap = 0;

extern number x1,y1,x2,y2;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 pixel_coords)
{
	mat2 rotation = mat2(x1, y1, x2, y2);

	vec2 uv = vec2((0.5 - texture_coords.x)/zoomx, (offset - texture_coords.y)/(zoomy*fov)) * rotation;
	vec2 uv2 = vec2(uv.x / (texture_coords.y) + x, uv.y / (texture_coords.y) + y);
	
	if (wrap == 0 && (uv2.x < 0.0 || uv2.x > 1.0 || uv2.y < 0.0 || uv2.y > 1.0)) {
		return vec4( 0.0,0.0,0.0,0.0 );
	} else {
		return texture2D(map,mod(uv2,1.0));
	}
}
]]

local function setRotation(cam,r)
	cam.r = r
	cam.x1 = sin(r); cam.y1 = cos(r)
	cam.x2 = -cos(r); cam.y2 = sin(r)
	return cam
end

local function getRotation(cam)
	return cam.r%tau
end

local function setPosition(cam,x,y,r)
	cam.x = x
	cam.y = y
	return cam
end

local function getPosition(cam) return cam.x, cam.y end

local function getX(cam) return cam.x end
local function getY(cam) return cam.y end

local function setZoom(cam,z) cam.z = z return cam end
local function getZoom(cam,z) return cam.z end

local function setFov(cam,f) cam.f = f return cam end
local function getFov(cam,f) return cam.f end

local function setOffset(cam,o) cam.o = o return cam end
local function getOffset(cam,o) return cam.o end

local function newCamera(sw,sh,x,y,r,z,f,o)
	local cam = { __playmat=true,
		sw=sw or 800,
		sh=sh or 600,
		x=x or 0,
		y=y or 0,
		r=r or 0,
		z=z or 32,
		f=f or 1,
		o=o or 1,
		x1=0,
		y1=0,
		x2=0,
		y2=0,
		setRotation = setRotation,
		getRotation = getRotation,
		setPosition = setPosition,
		getPosition = getPosition,
		getX = getX,
		getY = getY,
		setZoom = setZoom,
		getZoom = getZoom,
		setFov = setFov,
		getFov = getFov,
		setOffset = setOffset,
		getOffset = getOffset
	}
	cam.rendercanvas = lg.newCanvas(cam.sw,cam.sh)
	cam.canvas = lg.newCanvas(cam.sw,cam.sh)
	
	setRotation(cam,cam.r)

	return cam
end

local function drawPlane(cam, image, ox,oy, x,y,w,h)
	lg.setShader(shader)
	shader:send('map', image)
	shader:send('x', (cam.x - (ox or 0))/image:getWidth())
	shader:send('y', (cam.y - (oy or 0))/image:getHeight())
	shader:send('zoomx', (image:getWidth())/cam.z)
	shader:send('zoomy', (image:getHeight())/cam.z)
	shader:send('fov', cam.f)
	shader:send('offset', cam.o)
	
	shader:send('x1', cam.x1) shader:send('y1', cam.y1)
	shader:send('x2', cam.x2) shader:send('y2', cam.y2)
	
	local canvas = cam.canvas
	canvas:renderTo(function()
		lg.push()
		lg.origin()
		lg.clear() --It's fun to comment this out sometimes :D
		lg.draw(cam.rendercanvas)
		lg.pop()
	end)
	lg.setShader()
	lg.draw(canvas, x or 0,y or 0, 0, cam.sw/canvas:getWidth(),cam.sh/canvas:getHeight())
end

--It took a lot of tinkering, but it finally works!
--Thank my lack of understanding :P
local function toScreen(cam,x,y)
	--Gets the x,y position relative to the camera and zooms it out for good measure.
	local obj_x = -((cam.x-x)/cam.z)
	local obj_y = ((cam.y-y)/cam.z)
	--Rotate by the camera angle, the final translation in 2d space!
	local space_x = -(obj_x*cam.x1) - (obj_y*cam.y1)
	local space_y = ((obj_x*cam.x2) + (obj_y*cam.y2))*cam.f
	--Project to screen!
	local distance = 1-(space_y) 
	local screen_x = ( space_x / distance )*cam.o *cam.sw+cam.sw/2
	local screen_y = ( (space_y + (cam.o-1)) / distance )*cam.sh+cam.sh
	
	--Should be approximately one pixel on the plane
	local size = ((1/distance)/cam.z*cam.o)*cam.sw
	
	return screen_x, screen_y, size
end

local function toWorld(cam,x,y)
	local sx,sy = (cam.sw/2-x)*cam.z/(cam.sw/cam.sh), ((cam.o*cam.sh)-y)*(cam.z/cam.f)
	local rx,ry = (sx*cam.x1) + (sy*cam.y1), (sx*cam.x2) + (sy*cam.y2)
	return (rx/y + cam.x), (ry/y + cam.y)
end

--Sprites:
local buffer = {}

local function placeSprite(cam, ...)
	local arg = {...}
	
	local q = type(arg[2]) ~= "number" and 1 or 0
	
	local wx,wy,s=toScreen(cam,arg[2+q] or 0,arg[3+q] or 0)
	arg[2+q],arg[3+q] = wx, wy

	local width, height
	if q == 0 then
		width, height = arg[1]:getDimensions()
	else
		local x,y,w,h = arg[2]:getViewport()
		width, height = w,h
	end
	
	local sx2 = (s*(arg[5+q] or 1))/width
	local sy2 = arg[6+q] and (s*arg[6+q])/height or sx2
	arg[5+q] = sx2
	arg[6+q] = sy2
	
	arg[7+q] = arg[7+q] or width/2 
	arg[8+q] = arg[8+q] or height
	
	arg.dist = s
	if s*min(sx2,sy2) > 1 then
		if not buffer[cam] then buffer[cam]={} end
		insert(buffer[cam],arg)
	end
end

local function renderSprites(cam)
	if buffer[cam] then
		sort(buffer[cam],function(a,b) return a.dist < b.dist end)
		for i=1,#buffer[cam] do local v=buffer[cam][i]
			lg.draw(unpack(v))
		end
		buffer[cam] = nil
	end
end

PM.newCamera = newCamera
PM.drawPlane = drawPlane
PM.toScreen = toScreen
PM.toWorld = toWorld
PM.placeSprite = placeSprite
PM.renderSprites = renderSprites 

return PM