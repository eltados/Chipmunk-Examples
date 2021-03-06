# I wrote this to help understand the basics of Chipmunk 2D physics
# If you find anything wrong or disagree with something, please let me know.

# Me, Phil Cooper-King
#     Email: <phil@cooperking.net>
#     Website: http://www.mootgames.com

# Gosu:
#     Homepage: http://libgosu.org/
#     Google Code: http://code.google.com/p/gosu/

# Chipmunk:
#     Homepage: http://wiki.slembcke.net/main/published/Chipmunk

# This prog tries to recreate a 2D swing bridge


# This requires gosu gem has been installed and the chipmunk bundle.
# The mac version of chipmunk has come with this package.
# For Linux and Windows you'll need to build the package yourself
require 'rubygems'
require 'gosu'
require 'chipmunk'

SCREEN_WIDTH = 800
SCREEN_HEIGHT = 600
FULLSCREEN = false
INFINITY = 1.0/0

# This seems to be the standard helpers for chipmunk to/from gosu
class Numeric 
  def gosu_to_radians
    (self - 90) * Math::PI / 180.0
  end
  
  def radians_to_gosu
    self * 180.0 / Math::PI + 90
  end
  
  def radians_to_vec2
    CP::Vec2.new(Math::cos(self), Math::sin(self))
  end
end

# Generates the Walls for the objects to bounce off
class Wall
  
  attr_reader :a, :b
  
  def initialize(window, shape, pos)
    @window = window
    
    @color = Gosu::black
    
    @a = CP::Vec2.new(shape[0][0], shape[0][1])
    @b = CP::Vec2.new(shape[1][0], shape[1][1])
    
    @body = CP::Body.new(INFINITY, INFINITY)
    @body.p = CP::Vec2.new(pos[0], pos[1])
    @body.v = CP::Vec2.new(0,0)
    
    @shape = CP::Shape::Segment.new(@body, @a, @b, 1)
    @shape.e = 0.1
    @shape.u = 0.5
    
    @window.space.add_static_shape(@shape)
    
    @shape.collision_type = :wall
  end
  
  def draw
    @window.draw_line(@body.p.x + a.x, @body.p.y + a.y, @color,
                      @body.p.x + b.x, @body.p.y + b.y, @color,
                      1)
  end
  
end

class Bridge
  
  attr_accessor :bodies, :shapes
  
  BRIDGE_WIDTH = 2
  
  def initialize(window, pos, segments, sag)
    @window = window
    @pos = pos
    @segments = segments
    @sag = sag
    @seg_length = (((Gosu::distance(@pos[0][0], @pos[0][1], @pos[1][0], @pos[1][1]) + @sag) / @segments) / 2)
    
    @colors = {:black => Gosu::black}
    
    @bodies = []
    @shapes = []
    @joints = []

    @shape_verts = [CP::Vec2.new(-@seg_length, -BRIDGE_WIDTH),
                    CP::Vec2.new(-@seg_length, BRIDGE_WIDTH),
                    CP::Vec2.new(@seg_length, BRIDGE_WIDTH),
                    CP::Vec2.new(@seg_length, -BRIDGE_WIDTH)]
    
    post_anchors = [CP::Vec2.new(-1, -1),
                    CP::Vec2.new(1, -1),
                    CP::Vec2.new(-1, 1),
                    CP::Vec2.new(1, 1)]

    # CREATING THE BODIES, SHAPES AND JOINTS OF THE BRIDGE
    @segments.times do
      @bodies << CP::Body.new(60, 10000)
      @shapes << CP::Shape::Poly.new(@bodies[-1], @shape_verts, CP::Vec2.new(0,0))
      # MOVING BACKWARDS THROUGH THE ARRAY
      if @bodies[-2]
        @joints << CP::Joint::Pin.new(@bodies[-2], @bodies[-1], CP::Vec2.new((@seg_length / 2), -BRIDGE_WIDTH), CP::Vec2.new((-@seg_length / 2), -BRIDGE_WIDTH))
      end
    end
    
    2.times do
      @bodies << CP::Body.new(INFINITY, INFINITY)
      @shapes << CP::Shape::Poly.new(@bodies[-1], post_anchors, CP::Vec2.new(0,0))    
    end
    
    @joints << CP::Joint::Pin.new(@bodies[-1], @bodies[0], CP::Vec2.new(0, 0), CP::Vec2.new(-@seg_length / 2, -BRIDGE_WIDTH))
    @joints << CP::Joint::Pin.new(@bodies[-2], @bodies[-3], CP::Vec2.new(0, 0), CP::Vec2.new(@seg_length / 2, -BRIDGE_WIDTH))
    
    # SETTINGS OF THE BODIES AND SHAPES
    @segments.times do |seg|
      @bodies[seg].p = CP::Vec2.new(@pos[0][0] + @seg_length * seg, @pos[0][1])
      @bodies[seg].v = CP::Vec2.new(0,0)
      @shapes[seg].e = 0.1
      @shapes[seg].u = 1
    end
    
    # MOVE THE ANCHOR POINTS INTO POSITION
    @bodies[-1].p = CP::Vec2.new(@pos[0][0], @pos[0][1])
    @bodies[-2].p = CP::Vec2.new(@pos[1][0], @pos[1][1])
    
    # ADD THE STATIC SHAPES TO CHIP SPACE
    @window.space.add_static_shape(@shapes[-1])
    @window.space.add_static_shape(@shapes[-2])
    @window.space.add_joint(@joints[-1])
    @window.space.add_joint(@joints[-2])
    
    (@segments).times do |seg|
      @window.space.add_body(@bodies[seg]) if @bodies[seg]
      @window.space.add_shape(@shapes[seg]) if @shapes[seg]
      @window.space.add_joint(@joints[seg]) if @joints[seg]
      @shapes[seg].collision_type = :seg if @shapes[seg] # CREATING HANDLES FOR THEM
    end
    
    # REMOVING THE COLLISIONS OF THE BRIDGE AND WALLS, SO THAT IT DOESN'T BOUNCE OFF ITSELF, OR THE CLIFF
    @window.space.add_collision_func(:seg, :wall, &nil)
    @window.space.add_collision_func(:seg, :seg, &nil)
    
  end
  
  def update
    @segments.times do |seg|
      @shapes[seg].body.reset_forces
    end
  end
  
  def draw
    # Draw each segment of the bridge
    @segments.times do |seg|    
      tl, bl, br, tr = self.rotate(seg) # top left, bot left, bot right, top right
      [[tl, tr], [tr, br], [br, bl], [bl, tl]].each do |p|
        # Draw the outline of the segment
        @window.draw_line(p[0][0], p[0][1], @colors[:black], p[1][0], p[1][1], @colors[:black], 3)
      end
    end
  end
  
  def rotate(seg)
    body = @bodies[seg]
    
    x0 = (@shape_verts[0].x * Math::cos(body.a)) - (@shape_verts[0].y * Math::sin(body.a)) + body.p.x
    y0 = (@shape_verts[0].y * Math::cos(body.a)) + (@shape_verts[0].x * Math::sin(body.a)) + body.p.y
    
    x1 = (@shape_verts[1].x * Math::cos(body.a)) - (@shape_verts[1].y * Math::sin(body.a)) + body.p.x  
    y1 = (@shape_verts[1].y * Math::cos(body.a)) + (@shape_verts[1].x * Math::sin(body.a)) + body.p.y

    x2 = (@shape_verts[2].x * Math::cos(body.a)) - (@shape_verts[2].y * Math::sin(body.a)) + body.p.x
    y2 = (@shape_verts[2].y * Math::cos(body.a)) + (@shape_verts[2].x * Math::sin(body.a)) + body.p.y

    x3 = (@shape_verts[3].x * Math::cos(body.a)) - (@shape_verts[3].y * Math::sin(body.a)) + body.p.x
    y3 = (@shape_verts[3].y * Math::cos(body.a)) + (@shape_verts[3].x * Math::sin(body.a)) + body.p.y
    
    return([[x0, y0], [x1, y1], [x2, y2], [x3, y3]])
  end
  
end

class Block
  
  attr_accessor :body, :shape
  
  BOX_SIZE = 6
  
  def initialize(window)
    @window = window
    @color = Gosu::black
    @timer = Gosu::milliseconds + 3000
    
    init_body_shape
  end
  
  def init_body_shape
    @body = CP::Body.new(50, 60)
    @body.p = CP::Vec2.new(200 + rand(SCREEN_WIDTH - 400), (rand(50) -50))
    @body.v = CP::Vec2.new(0,0)
    @body.a = (3 * Math::PI / 2.0)
    
    @shape_verts = [
                    CP::Vec2.new(-BOX_SIZE, BOX_SIZE),
                    CP::Vec2.new(BOX_SIZE, BOX_SIZE),
                    CP::Vec2.new(BOX_SIZE, -BOX_SIZE),
                    CP::Vec2.new(-BOX_SIZE, -BOX_SIZE),
                   ]

    @shape = CP::Shape::Poly.new(@body,
                                 @shape_verts,
                                 CP::Vec2.new(0,0))
    
    @shape.e = 1
    @shape.u = 0.3
    
    @window.space.add_body(@body)
    @window.space.add_shape(@shape)
    
    @timer = Gosu::milliseconds + 3000
  end
  
  def update
    if (@body.p.y > SCREEN_HEIGHT) || (@timer < Gosu::milliseconds)
      @window.space.remove_body(@body)
      @window.space.remove_shape(@shape)
      init_body_shape
    end
    @shape.body.reset_forces
  end
  
  def draw
    top_left, top_right, bottom_left, bottom_right = self.rotate
    @window.draw_quad(top_left.x, top_left.y, @color,
                      top_right.x, top_right.y, @color,
                      bottom_left.x, bottom_left.y, @color,
                      bottom_right.x, bottom_right.y, @color,
                      2)
  end
  
  def rotate
     half_diagonal = Math.sqrt(2) * (BOX_SIZE)
     [-45, +45, -135, +135].collect do |angle|
       CP::Vec2.new(@body.p.x + Gosu::offset_x(@body.a.radians_to_gosu + angle,
                                               half_diagonal),

                    @body.p.y + Gosu::offset_y(@body.a.radians_to_gosu + angle,
                                               half_diagonal))
    end
  end

end

# Game class
class Game < Gosu::Window
  
  attr_accessor :space
  
  SUBSTEPS = 10
  
  def initialize
    super(SCREEN_WIDTH, SCREEN_HEIGHT, FULLSCREEN)
    @mootlogo = Gosu::Image.new(self, "media/moot.png", false)
    @chiplogo = Gosu::Image.new(self, "media/chipmoot.png", false)
    self.caption = "Bridge"
    @colors = {:white => Gosu::white, :gray => Gosu::gray}
    
    @dt = (1.0/60.0)
    
    # CHIPMUNK SPACE
    @space = CP::Space.new
    @space.gravity = CP::Vec2.new(0, 10)
    
    @cliffs = []
    @cliffs << Wall.new(self, [[0, 0], [250, 20]], [0, 290])
    @cliffs << Wall.new(self, [[0, 0], [-250, 20]], [800, 290])
    @cliffs << Wall.new(self, [[0, 0], [-100, 200]], [250, 310])
    @cliffs << Wall.new(self, [[0, 0], [100, 200]], [550, 310])
    
    @blocks = []
    5.times do |b|
      @blocks << Block.new(self)
    end
    
    # The last two vars are segments, and additional sag to the bridge
    @bridge = Bridge.new(self, [[250, 310], [550, 310]], 10, 0)
  end
  
  def update
    SUBSTEPS.times do
      @bridge.update
      @blocks.each {|b| b.update}
      @space.step(@dt)
    end
  end
  
  def draw
    @blocks.each {|b| b.draw}
    
    @cliffs.each do |c|
      c.draw
    end
    
    @bridge.draw
    
    # Background Gradient
    self.draw_quad(0, 0, @colors[:white],
                   SCREEN_WIDTH, 0, @colors[:white],
                   0, SCREEN_HEIGHT, @colors[:gray],
                   SCREEN_WIDTH, SCREEN_HEIGHT, @colors[:gray],
                   0)
    
    # Drawing the logos
    @mootlogo.draw(SCREEN_WIDTH - 83, SCREEN_HEIGHT - 43, 1)
    @chiplogo.draw(10, SCREEN_HEIGHT - 43, 1)
  end
  
  # Quit the prog
  def button_down(id)
    if id == Gosu::Button::KbEscape
      close
    end
  end

  
end

Game.new.show