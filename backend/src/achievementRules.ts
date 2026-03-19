/** Статистика пользователя — те же поля, что в /users/.../stats */
export type UserEventStats = {
  created_events_count: number;
  total_going_to_my_events_count: number;
  events_i_going_count: number;
  followers_count: number;
};

export type AchievementDto = {
  id: string;
  title: string;
  description: string;
  icon_key: string;
  earned: boolean;
};

/**
 * Достижения по текущей статистике (без отдельной таблицы в БД).
 * Позже можно хранить earned_at в user_achievements и подмешивать сюда.
 */
export function buildAchievementsFromStats(stats: UserEventStats): AchievementDto[] {
  const s = stats;
  const list: AchievementDto[] = [
    {
      id: 'first_meetup',
      title: 'Первый шаг',
      description: 'Создать первую встречу на карте.',
      icon_key: 'add_location',
      earned: s.created_events_count >= 1,
    },
    {
      id: 'organizer',
      title: 'Организатор',
      description: 'Создать 5 встреч.',
      icon_key: 'event',
      earned: s.created_events_count >= 5,
    },
    {
      id: 'guest',
      title: 'В гостях',
      description: 'Отметиться «Приду» хотя бы на одной встрече.',
      icon_key: 'celebration',
      earned: s.events_i_going_count >= 1,
    },
    {
      id: 'social',
      title: 'На виду',
      description: 'Получить первого подписчика.',
      icon_key: 'person_add',
      earned: s.followers_count >= 1,
    },
    {
      id: 'crowd_pleaser',
      title: 'Сбор народа',
      description: 'Суммарно 10+ отметок «Приду» на ваших встречах.',
      icon_key: 'groups',
      earned: s.total_going_to_my_events_count >= 10,
    },
    {
      id: 'legend',
      title: 'Легенда (скоро)',
      description: 'Секретное достижение — скоро добавим условие.',
      icon_key: 'military_tech',
      earned: false,
    },
  ];
  return list;
}
