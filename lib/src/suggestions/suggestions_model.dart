import 'dart:convert';

class SuggestionsModel {
  final dynamic data;
  final bool willCloseSuggestionBox;
  SuggestionsModel({
    required this.data,
    this.willCloseSuggestionBox = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'data': data,
      'willCloseSuggestionBox': willCloseSuggestionBox,
    };
  }

  factory SuggestionsModel.fromMap(Map<String, dynamic> map) {
    return SuggestionsModel(
      data: map['data'],
      willCloseSuggestionBox: map['willCloseSuggestionBox'] ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory SuggestionsModel.fromJson(String source) =>
      SuggestionsModel.fromMap(json.decode(source));

  @override
  String toString() =>
      'SuggestionsModel(data: $data, willCloseSuggestionBox: $willCloseSuggestionBox)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SuggestionsModel &&
        other.data == data &&
        other.willCloseSuggestionBox == willCloseSuggestionBox;
  }

  @override
  int get hashCode => data.hashCode ^ willCloseSuggestionBox.hashCode;
}
