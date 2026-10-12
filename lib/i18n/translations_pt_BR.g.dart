///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:slang/generated.dart';
import 'translations.g.dart';

// Path: <root>
class TranslationsPtBr extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsPtBr({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.ptBr,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <pt-BR>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsPtBr _root = this; // ignore: unused_field

	@override 
	TranslationsPtBr $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsPtBr(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$app$pt_BR app = _Translations$app$pt_BR._(_root);
	@override late final _Translations$nav$pt_BR nav = _Translations$nav$pt_BR._(_root);
	@override late final _Translations$window$pt_BR window = _Translations$window$pt_BR._(_root);
	@override late final _Translations$settings$pt_BR settings = _Translations$settings$pt_BR._(_root);
}

// Path: app
class _Translations$app$pt_BR extends Translations$app$en {
	_Translations$app$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get name => 'RML Launcher';
}

// Path: nav
class _Translations$nav$pt_BR extends Translations$nav$en {
	_Translations$nav$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get home => 'Início';
	@override String get library => 'Biblioteca';
	@override String get store => 'Loja';
	@override String get search => 'Buscar';
	@override String get settings => 'Configurações';
	@override String searchShortcut({required Object modifier}) => '${modifier} K';
}

// Path: window
class _Translations$window$pt_BR extends Translations$window$en {
	_Translations$window$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get minimize => 'Minimizar';
	@override String get maximize => 'Maximizar';
	@override String get close => 'Fechar';
}

// Path: settings
class _Translations$settings$pt_BR extends Translations$settings$en {
	_Translations$settings$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get appearance => 'Aparência';
	@override String get colorTheme => 'Tema de cores';
	@override String get mode => 'Modo';
	@override String get reduceMotion => 'Reduzir movimento';
	@override String get language => 'Idioma';
	@override String get about => 'Sobre';
	@override String appVersion({required Object version}) => 'RML Launcher ${version}';
	@override String nativeVersion({required Object version}) => 'Biblioteca nativa ${version}';
	@override late final _Translations$settings$palette$pt_BR palette = _Translations$settings$palette$pt_BR._(_root);
	@override late final _Translations$settings$modes$pt_BR modes = _Translations$settings$modes$pt_BR._(_root);
	@override late final _Translations$settings$motion$pt_BR motion = _Translations$settings$motion$pt_BR._(_root);
	@override late final _Translations$settings$languages$pt_BR languages = _Translations$settings$languages$pt_BR._(_root);
}

// Path: settings.palette
class _Translations$settings$palette$pt_BR extends Translations$settings$palette$en {
	_Translations$settings$palette$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get blackAndBlue => 'Preto e azul';
	@override String get stoneAndSand => 'Pedra e areia';
	@override String get studioGrey => 'Cinza do Studio';
}

// Path: settings.modes
class _Translations$settings$modes$pt_BR extends Translations$settings$modes$en {
	_Translations$settings$modes$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get system => 'Sistema';
	@override String get dark => 'Escuro';
	@override String get light => 'Claro';
}

// Path: settings.motion
class _Translations$settings$motion$pt_BR extends Translations$settings$motion$en {
	_Translations$settings$motion$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get system => 'Sistema';
	@override String get turnedOn => 'Ligado';
	@override String get turnedOff => 'Desligado';
}

// Path: settings.languages
class _Translations$settings$languages$pt_BR extends Translations$settings$languages$en {
	_Translations$settings$languages$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get english => 'English';
	@override String get portuguese => 'Português (Brasil)';
}

/// The flat map containing all translations for locale <pt-BR>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsPtBr {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'app.name' => 'RML Launcher',
			'nav.home' => 'Início',
			'nav.library' => 'Biblioteca',
			'nav.store' => 'Loja',
			'nav.search' => 'Buscar',
			'nav.settings' => 'Configurações',
			'nav.searchShortcut' => ({required Object modifier}) => '${modifier} K',
			'window.minimize' => 'Minimizar',
			'window.maximize' => 'Maximizar',
			'window.close' => 'Fechar',
			'settings.appearance' => 'Aparência',
			'settings.colorTheme' => 'Tema de cores',
			'settings.mode' => 'Modo',
			'settings.reduceMotion' => 'Reduzir movimento',
			'settings.language' => 'Idioma',
			'settings.about' => 'Sobre',
			'settings.appVersion' => ({required Object version}) => 'RML Launcher ${version}',
			'settings.nativeVersion' => ({required Object version}) => 'Biblioteca nativa ${version}',
			'settings.palette.blackAndBlue' => 'Preto e azul',
			'settings.palette.stoneAndSand' => 'Pedra e areia',
			'settings.palette.studioGrey' => 'Cinza do Studio',
			'settings.modes.system' => 'Sistema',
			'settings.modes.dark' => 'Escuro',
			'settings.modes.light' => 'Claro',
			'settings.motion.system' => 'Sistema',
			'settings.motion.turnedOn' => 'Ligado',
			'settings.motion.turnedOff' => 'Desligado',
			'settings.languages.english' => 'English',
			'settings.languages.portuguese' => 'Português (Brasil)',
			_ => null,
		};
	}
}
