import 'package:mocktail/mocktail.dart';
import 'package:project_lifestable/features/dashboard/domain/entities/domain_entity.dart';
import 'package:project_lifestable/features/dashboard/domain/repositories/domain_repository.dart';
import 'package:project_lifestable/features/notes/domain/entities/note_entity.dart';
import 'package:project_lifestable/features/notes/domain/repositories/note_repository.dart';
import 'package:project_lifestable/features/tasks/domain/entities/task_entity.dart';
import 'package:project_lifestable/features/tasks/domain/repositories/task_repository.dart';

class MockTaskRepository extends Mock implements TaskRepository {}

class MockNoteRepository extends Mock implements NoteRepository {}

class MockDomainRepository extends Mock implements DomainRepository {}

// Register fallback values for complex types used in any() matchers.
void registerFallbacks() {
  registerFallbackValue(
    TaskEntity(id: 'fb', domainId: 'fb-domain', title: 'Fallback'),
  );
  registerFallbackValue(
    NoteEntity(
      id: 'fb',
      userId: 'fb-user',
      domainId: 'fb-domain',
      title: 'Fallback',
      content: '',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    ),
  );
  registerFallbackValue(
    const DomainEntity(id: 'fb', name: 'Fallback', iconCode: 0, colorHex: '#000000'),
  );
  registerFallbackValue(TaskStatus.todo);
}
