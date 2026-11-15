import '../../domain/entities/greeting.dart';

/// Model (DTO): conhece o formato externo (JSON) e sabe converter-se em
/// entidade de domínio. A entidade nunca conhece o model.
final class GreetingModel {
  const GreetingModel({required this.message, required this.createdAt});

  factory GreetingModel.fromJson(Map<String, dynamic> json) => GreetingModel(
        message: json['message'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  final String message;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'message': message,
        'created_at': createdAt.toIso8601String(),
      };

  Greeting toEntity() => Greeting(message: message, createdAt: createdAt);
}
