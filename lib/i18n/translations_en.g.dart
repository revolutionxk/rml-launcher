///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

part of 'translations.g.dart';

// Path: <root>
typedef TranslationsEn = Translations; // ignore: unused_element
class Translations with BaseTranslations<AppLocale, Translations> {
	/// Returns the current translations of the given [context].
	///
	/// Usage:
	/// final t = Translations.of(context);
	static Translations of(BuildContext context) => InheritedLocaleData.of<AppLocale, Translations>(context).translations;

	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	Translations({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.en,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <en>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	dynamic operator[](String key) => _meta.getTranslation(key);

	late final Translations _root = this; // ignore: unused_field

	Translations $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => Translations(meta: meta ?? this.$meta);

	// Translations
	late final Translations$app$en app = Translations$app$en.internal(_root);
	late final Translations$nav$en nav = Translations$nav$en.internal(_root);
	late final Translations$window$en window = Translations$window$en.internal(_root);
	late final Translations$settings$en settings = Translations$settings$en.internal(_root);
}

// Path: app
class Translations$app$en {
	Translations$app$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'RML Launcher'
	String get name => 'RML Launcher';
}

// Path: nav
class Translations$nav$en {
	Translations$nav$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Home'
	String get home => 'Home';

	/// en: 'Library'
	String get library => 'Library';

	/// en: 'Store'
	String get store => 'Store';

	/// en: 'Search'
	String get search => 'Search';

	/// en: 'Settings'
	String get settings => 'Settings';

	/// en: '{modifier} K'
	String searchShortcut({required Object modifier}) => '${modifier} K';
}

// Path: window
class Translations$window$en {
	Translations$window$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Minimize'
	String get minimize => 'Minimize';

	/// en: 'Maximize'
	String get maximize => 'Maximize';

	/// en: 'Close'
	String get close => 'Close';
}

// Path: settings
class Translations$settings$en {
	Translations$settings$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Appearance'
	String get appearance => 'Appearance';

	/// en: 'Color theme'
	String get colorTheme => 'Color theme';

	/// en: 'Mode'
	String get mode => 'Mode';

	/// en: 'Reduce motion'
	String get reduceMotion => 'Reduce motion';

	/// en: 'Language'
	String get language => 'Language';

	/// en: 'About'
	String get about => 'About';

	/// en: 'RML Launcher {version}'
	String appVersion({required Object version}) => 'RML Launcher ${version}';

	/// en: 'Native library {version}'
	String nativeVersion({required Object version}) => 'Native library ${version}';

	late final Translations$settings$palette$en palette = Translations$settings$palette$en.internal(_root);
	late final Translations$settings$modes$en modes = Translations$settings$modes$en.internal(_root);
	late final Translations$settings$motion$en motion = Translations$settings$motion$en.internal(_root);
	late final Translations$settings$languages$en languages = Translations$settings$languages$en.internal(_root);
}

// Path: settings.palette
class Translations$settings$palette$en {
	Translations$settings$palette$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Black and blue'
	String get blackAndBlue => 'Black and blue';

	/// en: 'Stone and sand'
	String get stoneAndSand => 'Stone and sand';

	/// en: 'Studio grey'
	String get studioGrey => 'Studio grey';
}

// Path: settings.modes
class Translations$settings$modes$en {
	Translations$settings$modes$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'System'
	String get system => 'System';

	/// en: 'Dark'
	String get dark => 'Dark';

	/// en: 'Light'
	String get light => 'Light';
}

// Path: settings.motion
class Translations$settings$motion$en {
	Translations$settings$motion$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'System'
	String get system => 'System';

	/// en: 'On'
	String get turnedOn => 'On';

	/// en: 'Off'
	String get turnedOff => 'Off';
}

// Path: settings.languages
class Translations$settings$languages$en {
	Translations$settings$languages$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'English'
	String get english => 'English';

	/// en: 'Português (Brasil)'
	String get portuguese => 'Português (Brasil)';
}

/// The flat map containing all translations for locale <en>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on Translations {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'app.name' => 'RML Launcher',
			'nav.home' => 'Home',
			'nav.library' => 'Library',
			'nav.store' => 'Store',
			'nav.search' => 'Search',
			'nav.settings' => 'Settings',
			'nav.searchShortcut' => ({required Object modifier}) => '${modifier} K',
			'window.minimize' => 'Minimize',
			'window.maximize' => 'Maximize',
			'window.close' => 'Close',
			'settings.appearance' => 'Appearance',
			'settings.colorTheme' => 'Color theme',
			'settings.mode' => 'Mode',
			'settings.reduceMotion' => 'Reduce motion',
			'settings.language' => 'Language',
			'settings.about' => 'About',
			'settings.appVersion' => ({required Object version}) => 'RML Launcher ${version}',
			'settings.nativeVersion' => ({required Object version}) => 'Native library ${version}',
			'settings.palette.blackAndBlue' => 'Black and blue',
			'settings.palette.stoneAndSand' => 'Stone and sand',
			'settings.palette.studioGrey' => 'Studio grey',
			'settings.modes.system' => 'System',
			'settings.modes.dark' => 'Dark',
			'settings.modes.light' => 'Light',
			'settings.motion.system' => 'System',
			'settings.motion.turnedOn' => 'On',
			'settings.motion.turnedOff' => 'Off',
			'settings.languages.english' => 'English',
			'settings.languages.portuguese' => 'Português (Brasil)',
			_ => null,
		};
	}
}
