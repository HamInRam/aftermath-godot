extends Node

const ENTRY_SCENE := preload("res://scenes/ui/entry_loadout_overlay.tscn")
const ICONS := preload("res://utility/weapon_ui_icon_factory.gd")
const TEST_SAVE_PATH := "user://aftermath_visual_loadout_test.json"

var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_data: Dictionary = Progression.data.duplicate(true)
	var original_save_path: String = Progression.save_path
	Progression.save_path = TEST_SAVE_PATH
	Progression.reset_progress(false)
	var weapon_hashes := {}
	for weapon_id in WeaponPlatformCatalog.get_weapon_ids():
		var texture := ICONS.weapon_icon(weapon_id)
		_expect(texture != null and texture.get_size() == Vector2(64, 24), "%s needs a strict 64x24 pixel preview" % weapon_id)
		var image := texture.get_image()
		_expect(not image.is_empty() and _opaque_pixel_count(image) >= 24, "%s preview should contain a readable silhouette" % weapon_id)
		weapon_hashes[image.get_data().hex_encode().hash()] = true
	_expect(weapon_hashes.size() >= ceili(WeaponPlatformCatalog.get_weapon_ids().size() * 0.875), "at least 87.5% of enabled firearms must retain distinct silhouettes")
	for attachment_id in AttachmentCatalog.ATTACHMENTS:
		var texture := ICONS.attachment_icon(str(attachment_id))
		_expect(texture != null and texture.get_size() == Vector2(16, 16), "%s needs a strict 16x16 part icon" % attachment_id)
		_expect(_opaque_pixel_count(texture.get_image()) >= 8, "%s icon should be visible at native resolution" % attachment_id)
	var part_preview_hashes := {}
	for attachment_id in AttachmentCatalog.ATTACHMENTS:
		var preview := ICONS.attachment_preview(str(attachment_id))
		_expect(preview != null and preview.get_size() == Vector2(32, 20), "%s needs an individual 32x20 workbench picture" % attachment_id)
		part_preview_hashes[preview.get_image().get_data().hex_encode().hash()] = true
	_expect(part_preview_hashes.size() >= AttachmentCatalog.ATTACHMENTS.size() - 2, "attachment workbench pictures should remain visually distinct")
	var overlay = ENTRY_SCENE.instantiate()
	overlay.configure("NIGHTCLUB ENTRY")
	add_child(overlay)
	await get_tree().process_frame
	var panel := overlay.get_node("Root/Panel") as Control
	var panel_rect := panel.get_rect()
	_expect(panel_rect.position.x >= 4.0 and panel_rect.position.y >= 4.0 and panel_rect.end.x <= 317.0 and panel_rect.end.y <= 176.0, "entry bench must be a contained overlay with the live level visible around it")
	_expect(panel.clip_contents, "entry bench should hard-clip future controls to its authored panel bounds")
	var footer_rect := (overlay.get_node("Root/Panel/FooterBackground") as ColorRect).get_rect()
	var deploy_rect := (overlay.get_node("Root/Panel/Deploy") as Button).get_rect()
	_expect(footer_rect.has_point(deploy_rect.position) and footer_rect.has_point(deploy_rect.end - Vector2.ONE), "deployment confirmation must remain fully inside the dedicated footer")
	_expect(deploy_rect.end.x <= panel.size.x - 4.0 and deploy_rect.end.y <= panel.size.y - 4.0, "the primary loadout action needs a visible safe margin from every panel edge")
	for button in overlay.attachment_buttons:
		_expect(not (button as Button).get_rect().intersects(deploy_rect), "attachment hardpoints must never overlap the deployment action")
	_expect((overlay.get_node("Root/Dim") as ColorRect).color.a <= 0.5, "entry bench backdrop should dim rather than replace the level")
	_expect(overlay.get_node("Root/Panel/Inventory0/Image").texture != null, "entry bench should show the primary weapon picture")
	_expect(overlay.get_node("Root/Panel/Inventory1/Image").texture != null, "entry bench should show the secondary weapon picture")
	for preset in overlay.preset_cards:
		_expect((preset.image as TextureRect).texture != null, "every preset card needs a visual weapon preview")
	for row in overlay.get_node("Root/Panel/AvailableRows").get_children():
		if row.visible: _expect(row.get_node("Image").texture != null, "every visible available-platform row needs its own firearm silhouette")
	var visible_categories := 0
	for button in overlay.category_buttons:
		if button.visible:
			visible_categories += 1
			_expect(button.icon == null and not button.text.is_empty(), "weapon category filters should use readable names instead of pictures")
	_expect(visible_categories >= 7, "primary weapons should be separated into visible category filters")
	overlay.call("_select_category", "carbine")
	_expect(overlay.call("_available_weapons").size() == WeaponPlatformCatalog.get_class_weapon_ids("carbine").size(), "each category must expose the complete enabled roster, including locked requisitions")
	for button in overlay.attachment_buttons:
		_expect(button.icon != null and button.text.is_empty(), "each attachment hardpoint should use a pixel icon rather than a text button")
	overlay.call("_open_mod_interface", overlay.primary_id)
	await get_tree().process_frame
	_expect(is_instance_valid(overlay.mod_workbench), "right-click weapon flow should open an independent mod workbench")
	_expect(not overlay.get_node("Root").visible, "the loadout bench should yield focus while weapon modification is open")
	_expect(overlay.mod_workbench.get_node("Panel/WeaponPreview").texture != null, "mod workbench needs a large live firearm picture")
	for card in overlay.mod_workbench.part_cards:
		if (card.root as Control).visible: _expect((card.image as TextureRect).texture != null, "every compatible attachment card needs its own picture")
	overlay.call("_close_mod_interface")
	await get_tree().process_frame
	_expect(overlay.get_node("Root").visible, "closing modification should return to the staged loadout")
	overlay.queue_free()
	await get_tree().process_frame
	Progression.data = original_data
	Progression.save_path = original_save_path
	if FileAccess.file_exists(TEST_SAVE_PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	if failures == 0: print("visual loadout UI regression: PASS")
	get_tree().quit(failures)

func _opaque_pixel_count(image: Image) -> int:
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.01: count += 1
	return count

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
