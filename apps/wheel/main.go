package main

import (
	"database/sql"
	"flag"
	"fmt"
	"image/color"
	"log"
	"math"
	"math/rand"
	"net/http"
	"os"

	"github.com/codingconcepts/scale-spin/apps/pkg/models"
	"github.com/hajimehoshi/ebiten/v2"
	"github.com/hajimehoshi/ebiten/v2/ebitenutil"
	"github.com/hajimehoshi/ebiten/v2/inpututil"
	"github.com/hajimehoshi/ebiten/v2/text"
	"golang.org/x/image/font/basicfont"

	_ "github.com/jackc/pgx/v5/stdlib"
)

const (
	screenW = 640
	screenH = 640
)

var (
	scenarios = []models.Scenario{
		models.ScenarioScaleUpAP,
		models.ScenarioScaleDownAP,
		models.ScenarioScaleUpEU,
		models.ScenarioScaleDownEU,
		models.ScenarioScaleUpUS,
		models.ScenarioScaleDownUS,
		models.ScenarioFlashSale,
		models.ScenarioNewProduct,
		models.ScenarioScandal,
		models.ScenarioTest,
	}
)

func main() {
	dbURL := flag.String("url", "", "url to the database")
	flag.Parse()

	if *dbURL == "" {
		flag.Usage()
		os.Exit(2)
	}

	db, err := sql.Open("pgx", *dbURL)
	if err != nil {
		log.Fatalf("error opening database connection: %v", err)
	}

	ebiten.SetWindowSize(screenW, screenH)
	ebiten.SetWindowTitle("Scale Spin")
	ebiten.SetWindowResizingMode(ebiten.WindowResizingModeEnabled)

	game := NewGame(db)
	if err := ebiten.RunGame(game); err != nil {
		log.Fatalf("running game: %v", err)
	}
}

type Game struct {
	db               *sql.DB
	regionServices   map[string]*http.Client
	segments         []models.Scenario
	colors           []color.RGBA
	angle            float64
	angVel           float64
	spinning         bool
	centerX, centerY float64
	radius           float64
	lastResult       models.Scenario

	white1x1 *ebiten.Image
}

func NewGame(db *sql.DB) *Game {
	white := ebiten.NewImage(1, 1)
	white.Fill(color.White)

	return &Game{
		db:       db,
		segments: scenarios,
		colors:   palette(len(scenarios)),
		centerX:  screenW / 2,
		centerY:  screenH / 2,
		radius:   260,
		white1x1: white,
	}
}

func (g *Game) Update() error {
	if inpututil.IsMouseButtonJustPressed(ebiten.MouseButtonLeft) && !g.spinning {
		g.spinning = true
		g.lastResult = ""
		g.angVel = 0.4 + rand.Float64()*0.6
		g.angle += rand.Float64() * 2 * math.Pi
	}
	if g.spinning {
		g.angle += g.angVel
		g.angVel *= 0.97
		if g.angVel < 0.002 {
			g.spinning = false
			g.angVel = 0
			landed := g.segmentAtPointer()
			g.lastResult = landed
		}
	}
	return nil
}

func (g *Game) Draw(screen *ebiten.Image) {
	screen.Fill(color.RGBA{24, 26, 27, 255})
	g.drawWheel(screen)
	g.drawPointer(screen)

	ebitenutil.DebugPrintAt(screen, "Click to spin the wheel", 10, 10)
	if g.lastResult == "" {
		return
	}

	ebitenutil.DebugPrintAt(screen, string(g.lastResult), 10, screenH-20)

	if err := g.applyScenario(g.lastResult); err != nil {
		log.Printf("publish error: %v", err)
	}

	g.lastResult = ""
}

func (g *Game) applyScenario(s models.Scenario) error {
	log.Printf("publishing scenario: %s...", s)

	switch s {
	case models.ScenarioScaleUpAP:
		return g.updateDB(1, models.RegionAP)
	case models.ScenarioScaleDownAP:
		return g.updateDB(-1, models.RegionAP)

	case models.ScenarioScaleUpEU:
		return g.updateDB(1, models.RegionEU)
	case models.ScenarioScaleDownEU:
		return g.updateDB(-1, models.RegionEU)

	case models.ScenarioScaleUpUS:
		return g.updateDB(1, models.RegionUS)
	case models.ScenarioScaleDownUS:
		return g.updateDB(-1, models.RegionUS)

	case models.ScenarioNewProduct:
		return g.updateDB(5, models.RegionAP, models.RegionEU, models.RegionUS)
	case models.ScenarioFlashSale:
		return g.updateDB(10, models.RegionAP, models.RegionEU, models.RegionUS)
	case models.ScenarioScandal:
		return g.updateDB(5, models.RegionAP, models.RegionEU, models.RegionUS)

	default:
		return fmt.Errorf("unsupported scenario: %s", s)
	}
}

func (g *Game) updateDB(delta int, regions ...string) error {
	const stmt = `UPDATE workload
								SET workers = GREATEST(workers + $1, 0)
								WHERE region = ANY($2)`

	if _, err := g.db.Exec(stmt, delta, regions); err != nil {
		return fmt.Errorf("making request: %w", err)
	}

	return nil
}

func (g *Game) Layout(_, _ int) (int, int) {
	return screenW, screenH
}

func (g *Game) drawWheel(screen *ebiten.Image) {
	n := len(g.segments)
	if n == 0 {
		return
	}
	anglePer := 2 * math.Pi / float64(n)

	// Colored wedges
	for i := range n {
		start := float64(i)*anglePer + g.angle
		end := float64(i+1)*anglePer + g.angle
		g.drawWedge(screen, g.centerX, g.centerY, g.radius, start, end, g.colors[i])
	}

	// Labels
	face := basicfont.Face7x13
	for i := range n {
		mid := float64(i)*anglePer + anglePer/2 + g.angle
		r := g.radius * 0.62
		tx := int(g.centerX + r*math.Cos(mid))
		ty := int(g.centerY + r*math.Sin(mid))
		label := g.segments[i]
		b := text.BoundString(face, string(label))
		text.Draw(screen, string(label), face, tx-b.Dx()/2, ty+b.Dy()/2, color.Black)
	}

	for i := range n {
		a := float64(i)*anglePer + g.angle
		x2 := g.centerX + g.radius*math.Cos(a)
		y2 := g.centerY + g.radius*math.Sin(a)
		ebitenutil.DrawLine(screen, g.centerX, g.centerY, x2, y2, color.RGBA{0, 0, 0, 120})
	}

	hubR := g.radius * 0.18
	g.drawDisk(screen, g.centerX, g.centerY, hubR, color.RGBA{230, 230, 230, 255})
}

func (g *Game) drawPointer(screen *ebiten.Image) {
	pW := 30.0
	pH := 36.0
	x := g.centerX
	y := g.centerY - g.radius - 6

	tri := []ebiten.Vertex{
		{DstX: float32(x), DstY: float32(y + pH), SrcX: 0, SrcY: 0, ColorR: 1, ColorG: 1, ColorB: 1, ColorA: 1},
		{DstX: float32(x - pW/2), DstY: float32(y), SrcX: 0, SrcY: 0, ColorR: 1, ColorG: 1, ColorB: 1, ColorA: 1},
		{DstX: float32(x + pW/2), DstY: float32(y), SrcX: 0, SrcY: 0, ColorR: 1, ColorG: 1, ColorB: 1, ColorA: 1},
	}
	screen.DrawTriangles(tri, []uint16{0, 1, 2}, g.white1x1, nil)
}

func (g *Game) drawWedge(screen *ebiten.Image, cx, cy, r, start, end float64, c color.RGBA) {
	const step = 6.0 * (math.Pi / 180.0)
	for end < start {
		end += 2 * math.Pi
	}
	points := []struct{ x, y float64 }{{cx, cy}}
	for a := start; a <= end; a += step {
		points = append(points, struct{ x, y float64 }{cx + r*math.Cos(a), cy + r*math.Sin(a)})
	}
	points = append(points, struct{ x, y float64 }{cx + r*math.Cos(end), cy + r*math.Sin(end)})

	verts := make([]ebiten.Vertex, len(points))
	for i, p := range points {
		verts[i] = ebiten.Vertex{
			DstX: float32(p.x),
			DstY: float32(p.y),
			SrcX: 0, SrcY: 0,
			ColorR: float32(c.R) / 255, ColorG: float32(c.G) / 255, ColorB: float32(c.B) / 255, ColorA: float32(c.A) / 255,
		}
	}
	idx := make([]uint16, 0, (len(points)-2)*3)
	for i := 1; i < len(points)-1; i++ {
		idx = append(idx, 0, uint16(i), uint16(i+1))
	}
	screen.DrawTriangles(verts, idx, g.white1x1, nil)
}

func (g *Game) drawDisk(screen *ebiten.Image, cx, cy, r float64, col color.RGBA) {
	const step = 10.0 * (math.Pi / 180.0)
	points := []struct{ x, y float64 }{}
	for a := 0.0; a < 2*math.Pi+1e-6; a += step {
		points = append(points, struct{ x, y float64 }{cx + r*math.Cos(a), cy + r*math.Sin(a)})
	}
	verts := make([]ebiten.Vertex, len(points)+1)
	verts[0] = ebiten.Vertex{DstX: float32(cx), DstY: float32(cy), ColorR: float32(col.R) / 255, ColorG: float32(col.G) / 255, ColorB: float32(col.B) / 255, ColorA: float32(col.A) / 255}
	for i, p := range points {
		verts[i+1] = ebiten.Vertex{DstX: float32(p.x), DstY: float32(p.y), ColorR: float32(col.R) / 255, ColorG: float32(col.G) / 255, ColorB: float32(col.B) / 255, ColorA: float32(col.A) / 255}
	}
	idx := make([]uint16, 0, len(points)*3)
	for i := 1; i < len(verts)-1; i++ {
		idx = append(idx, 0, uint16(i), uint16(i+1))
	}
	screen.DrawTriangles(verts, idx, g.white1x1, nil)
}

func (g *Game) segmentAtPointer() models.Scenario {
	n := len(g.segments)
	if n == 0 {
		return ""
	}
	segAngle := 2 * math.Pi / float64(n)
	a := math.Mod(-math.Pi/2-g.angle, 2*math.Pi)
	if a < 0 {
		a += 2 * math.Pi
	}
	idx := max(int(math.Floor(a/segAngle)), 0)
	if idx >= n {
		idx = n - 1
	}
	return g.segments[idx]
}

func palette(n int) []color.RGBA {
	out := make([]color.RGBA, n)
	for i := range n {
		h := float64(i) / float64(n)
		out[i] = hsvToRGB(h, 0.45, 0.95)
	}
	return out
}

func hsvToRGB(h, s, v float64) color.RGBA {
	h = math.Mod(h, 1)
	hi := int(h * 6)
	f := h*6 - float64(hi)
	p := v * (1 - s)
	q := v * (1 - f*s)
	t := v * (1 - (1-f)*s)
	var r, g, b float64
	switch hi % 6 {
	case 0:
		r, g, b = v, t, p
	case 1:
		r, g, b = q, v, p
	case 2:
		r, g, b = p, v, t
	case 3:
		r, g, b = p, q, v
	case 4:
		r, g, b = t, p, v
	case 5:
		r, g, b = v, p, q
	}
	return color.RGBA{uint8(r * 255), uint8(g * 255), uint8(b * 255), 255}
}
