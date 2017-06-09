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

--Playmat Library v1.5
local PM = {}

local tau,cos,sin = math.pi*2,math.cos,math.sin
local insert,sort = table.insert,table.sort
local lg = love.graphics

--Camera
local function setRotation(cam,r)
	cam.r = r
	cam.x1 = sin(r); cam.y1 = cos(r)
	cam.x2 = -cos(r); cam.y2 = sin(r)
	return cam
end
local function setPosition(cam,x,y)
	cam.x = x
	cam.y = y
	return cam
end
local function setZoom(cam,z)
	cam.z = z
	return cam
end
local function setFov(cam,f)
	cam.f = f
	return cam
end
local function setOffset(cam,o)
	cam.o = o
	return cam
end

local function getRotation(cam) return cam.r % tau end
local function getPosition(cam) return cam.x, cam.y end
local function getX(cam) return cam.x end
local function getY(cam) return cam.y end
local function getZoom(cam,z) return cam.z end
local function getFov(cam,f) return cam.f end
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
		buffer={},
		setRotation = setRotation,
		setPosition = setPosition,
		setZoom = setZoom,
		setFov = setFov,
		setOffset = setOffset,
		getRotation = getRotation,
		getPosition = getPosition,
		getX = getX,
		getY = getY,
		getZoom = getZoom,
		getFov = getFov,
		getOffset = getOffset	
	}
	cam.rendercanvas = lg.newCanvas(cam.sw,cam.sh)
--	cam.canvas = lg.newCanvas(cam.sw,cam.sh)
	
	setRotation(cam,cam.r)

	return cam
end

--Plane:
local shader = lg.newShader [[
extern Image map;
extern number mapw;
extern number maph;
extern number x;
extern number y;
extern number zoom;
extern number fov;
extern number offset;
extern number wrap;

extern number x1,y1,x2,y2;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 pixel_coords)
{
	mat2 rotation = mat2(x1, y1, x2, y2);

	vec2 uv = vec2(
		(0.5 - texture_coords.x)*zoom,
		(offset - texture_coords.y)*(zoom/fov)
	) * rotation;
	vec2 uv2 = vec2(
		(uv.x / texture_coords.y + x) / mapw,
		(uv.y / texture_coords.y + y) / maph
	);
	
	if (wrap == 0 && (uv2.x < 0.0 || uv2.x > 1.0 || uv2.y < 0.0 || uv2.y > 1.0)) {
		return vec4( 0.0,0.0,0.0,0.0 );
	} else {
		return (Texel(map, mod(uv2,1.0) ) * color);
	}
}
]]

local function drawPlane(cam, image, ox,oy, sx,sy, wrap)
	shader:send('map', image)
	shader:send('mapw', image:getWidth()*(sx or 1))
	shader:send('maph', image:getHeight()*(sy or 1))
	shader:send('x', (cam.x - (ox or 0)) )
	shader:send('y', (cam.y - (oy or 0)) )
	shader:send('zoom', cam.z)
	shader:send('fov', cam.f)
	shader:send('offset', cam.o)
	shader:send('wrap', wrap and 1 or 0)
	
	shader:send('x1', cam.x1) shader:send('y1', cam.y1)
	shader:send('x2', cam.x2) shader:send('y2', cam.y2)
	
	lg.setShader(shader)
	lg.draw(cam.rendercanvas)
	lg.setShader()

end

local function toScreen(cam,x,y)
	local obj_x = -(cam.x-x)/cam.z
	local obj_y = (cam.y-y)/cam.z

	local space_x = (-obj_x*cam.x1 - obj_y*cam.y1)
	local space_y = (obj_x*cam.x2 + obj_y*cam.y2)*cam.f

	local distance = 1-(space_y) 
	local screen_x = ( space_x / distance )*cam.o*cam.sw+cam.sw/2
	local screen_y = ( (space_y + cam.o-1) / distance )*cam.sh+cam.sh
	
	--Should be approximately one pixel on the plane
	local size = ((1/distance)/cam.z*cam.o)*cam.sw
	
	return screen_x, screen_y, size
end

local function toWorld(cam,x,y)
	local sx = (cam.sw/2 - x)*cam.z/(cam.sw/cam.sh)
	local sy = (cam.o*cam.sh - y)*(cam.z/cam.f)
	
	local rotx = sx*cam.x1 + sy*cam.y1
	local roty = sx*cam.x2 + sy*cam.y2
	
	return (rotx/y + cam.x), (roty/y + cam.y)
end

--Sprites:
local function placeSprite(cam, ...)
	local arg = {...}
	
	--Q is 1 if there is a quad argument, otherwise it's 0.
	local q = type(arg[2]) ~= "number" and 1 or 0
	
	local wx,wy,s=toScreen(cam,arg[2+q] or 0,arg[3+q] or 0)

	local width, height
	if q == 0 then
		width, height = arg[1]:getDimensions()
	else
		local x,y,w,h = arg[2]:getViewport()
		width, height = w,h
	end
	
	local sx2 = (s*(arg[5+q] or 1))/width
	local sy2 = arg[6+q] and (s*arg[6+q])/height or sx2
	
	--If scale is flipped unintentionally. (When it is behind the camera.)
	if (sx2 > 0) == ((arg[5+q] or 1) > 0) and (sy2 > 0) == ((arg[6+q] or 1) > 0) then
		--We draw!
		arg[2+q],arg[3+q] = wx, wy
		
		arg[5+q] = sx2
		arg[6+q] = sy2
		
		arg[7+q] = arg[7+q] or width/2 
		arg[8+q] = arg[8+q] or height
		
		arg.color = {lg.getColor()}
		arg.dist = s
		
		insert(cam.buffer,arg)
	end
end

local function renderSprites(cam)
	if cam.buffer then
		local prevColor = {lg.getColor()}
		
		sort(cam.buffer,function(a,b) return a.dist < b.dist end)
		
		for i=1,#cam.buffer do
			local arg = cam.buffer[i]
			if arg.color then lg.setColor(arg.color) end
			lg.draw(unpack(arg)) 
		end
		
		cam.buffer = {}
		
		lg.setColor(prevColor)
	end
end

PM.newCamera = newCamera
PM.drawPlane = drawPlane
PM.toScreen = toScreen
PM.toWorld = toWorld
PM.placeSprite = placeSprite
PM.renderSprites = renderSprites 

return PM