class_name Compat
extends Reference

## O QUE O GODOT 4 TEM E O GODOT 3 NÃO (edição OpenGL ES 2.0).
##
## Funções pequenas com o mesmo comportamento das do Godot 4 que o jogo
## usava (inteiros, fatias de lista, arquivos, fontes com contorno, estado
## "static var" das classes), para os scripts do jogo mudarem o mínimo.

# ------------------------------------------------------------- números
static func imax(a: int, b: int) -> int:
	return a if a > b else b


static func imin(a: int, b: int) -> int:
	return a if a < b else b


static func iclamp(v: int, a: int, b: int) -> int:
	return imin(imax(v, a), b)


static func iabs(v: int) -> int:
	return -v if v < 0 else v


static func ifloor(x: float) -> int:
	return int(floor(x))


static func iceil(x: float) -> int:
	return int(ceil(x))


static func iround(x: float) -> int:
	return int(round(x))


## pingpong() do Godot 4: vai de 0 a `tamanho` e volta.
static func vaivem(t: float, tamanho: float) -> float:
	if tamanho == 0.0:
		return 0.0
	return tamanho - abs(fposmod(t, tamanho * 2.0) - tamanho)


## randi_range() do Godot 4 (os dois extremos valem).
static func rand_int(a: int, b: int) -> int:
	if b < a:
		var t := a
		a = b
		b = t
	return a + randi() % (b - a + 1)


## ProjectSettings.get_setting(nome, padrao) do Godot 4 (o 3 não tem o padrão).
static func config(nome: String, padrao = null):
	if ProjectSettings.has_setting(nome):
		return ProjectSettings.get_setting(nome)
	return padrao


# ------------------------------------------------------------- listas
## Array.slice(inicio, fim) do Godot 4: o `fim` NÃO entra, índices
## negativos contam do fim (no Godot 3 o fim entra e não aceita lista vazia).
static func fatia(lista, inicio: int, fim: int = 0x7FFFFFFF) -> Array:
	var n: int = lista.size()
	if inicio < 0:
		inicio = imax(n + inicio, 0)
	if fim < 0:
		fim = imax(n + fim, 0)
	fim = imin(fim, n)
	var r := []
	for i in range(inicio, fim):
		r.append(lista[i])
	return r


## pick_random() do Godot 4.
static func sorteia(lista):
	if lista.empty():
		return null
	return lista[randi() % lista.size()]


static func maior(lista) -> float:
	var m := -INF
	for v in lista:
		m = max(m, v)
	return m


# ------------------------------------------------------------- "static var"
## O Godot 3 não tem "static var": cada classe guarda o seu estado aqui,
## num dicionário só dela (devolvido por referência).
static func estado(nome: String) -> Dictionary:
	if not Engine.has_meta("compat_estados"):
		Engine.set_meta("compat_estados", {})
	var todos: Dictionary = Engine.get_meta("compat_estados")
	if not todos.has(nome):
		todos[nome] = {}
	return todos[nome]


# ------------------------------------------------------------- arquivos
static func existe_arquivo(caminho: String) -> bool:
	return File.new().file_exists(caminho)


static func existe_pasta(caminho: String) -> bool:
	return Directory.new().dir_exists(caminho)


static func criar_pasta(caminho: String) -> int:
	return Directory.new().make_dir_recursive(caminho)


static func apagar(caminho: String) -> int:
	return Directory.new().remove(caminho)


static func arquivos_em(pasta: String) -> PoolStringArray:
	var r := PoolStringArray()
	var d := Directory.new()
	if d.open(pasta) != OK:
		return r
	d.list_dir_begin(true, true)
	var f := d.get_next()
	while f != "":
		if not d.current_is_dir():
			r.append(f)
		f = d.get_next()
	d.list_dir_end()
	return r


static func ler_texto(caminho: String) -> String:
	var f := File.new()
	if f.open(caminho, File.READ) != OK:
		return ""
	var t := f.get_as_text()
	f.close()
	return t


static func gravar_texto(caminho: String, texto: String) -> bool:
	var f := File.new()
	if f.open(caminho, File.WRITE) != OK:
		return false
	f.store_string(texto)
	f.close()
	return true


# ------------------------------------------------------------- imagens
static func textura_de_imagem(img: Image, filtro := true, mipmaps := false) -> ImageTexture:
	var t := ImageTexture.new()
	var flags := 0
	if filtro:
		flags |= Texture.FLAG_FILTER
	if mipmaps:
		flags |= Texture.FLAG_MIPMAPS
	t.create_from_image(img, flags)
	return t


static func nova_imagem(largura: int, altura: int, mipmaps: bool, formato: int) -> Image:
	var img := Image.new()
	img.create(largura, altura, mipmaps, formato)
	return img


# ------------------------------------------------------------- fontes
## Fonte TTF num tamanho e contorno (cache: uma DynamicFont por combinação).
## O contorno é branco na fonte e ganha a cor no Label
## (font_outline_modulate) — a mesma fonte serve para qualquer cor.
static func fonte(nome: String, tamanho: int, contorno := 0) -> DynamicFont:
	var _fontes := estado("fontes")
	var _dados := estado("fontes_dados")
	var chave := "%s|%d|%d" % [nome, tamanho, contorno]
	if _fontes.has(chave):
		return _fontes[chave]
	if not _dados.has(nome):
		_dados[nome] = load("res://fontes/%s.ttf" % nome)
	var f := DynamicFont.new()
	f.font_data = _dados[nome]
	f.size = imax(tamanho, 1)
	f.outline_size = imax(contorno, 0)
	f.outline_color = Color.white
	f.use_filter = true
	f.use_mipmaps = false
	_fontes[chave] = f
	return f


## O que o LabelSettings do Godot 4 fazia num Label: fonte, tamanho, cor e
## contorno (e a sombra, que vira um contorno mais escuro deslocado).
static func estilo_rotulo(rot: Label, nome: String, tamanho: int, cor: Color, contorno := 0, cor_contorno := Color.black) -> void:
	rot.add_font_override("font", fonte(nome, tamanho, contorno))
	rot.add_color_override("font_color", cor)
	rot.add_color_override("font_outline_modulate", cor_contorno)
	rot.set_meta("estilo", [nome, tamanho, cor, contorno, cor_contorno])


## Troca só a cor de um Label já estilizado.
static func cor_rotulo(rot: Label, cor: Color) -> void:
	rot.add_color_override("font_color", cor)


## Troca só o tamanho de um Label já estilizado.
static func tamanho_rotulo(rot: Label, tamanho: int) -> void:
	if not rot.has_meta("estilo"):
		return
	var e: Array = rot.get_meta("estilo")
	estilo_rotulo(rot, e[0], tamanho, e[2], e[3], e[4])
