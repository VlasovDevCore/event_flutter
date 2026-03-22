/** Статистика пользователя — те же поля, что в /users/.../stats */
export type UserEventStats = {
  created_events_count: number;
  total_going_to_my_events_count: number;
  events_i_going_count: number;
  /** «Приду» только на чужих встречах (не как создатель своей) — для достижения «В гостях». */
  events_i_going_as_guest_count: number;
  followers_count: number;
};

export type AchievementDto = {
  id: string;
  title: string;
  description: string;
  icon_key: string;
  earned: boolean;
  /** 0..1 — заполнение полосы прогресса в приложении */
  progress: number;
  /** Текущее значение для подписи «N / M» под полосой */
  progress_current: number;
  /** Цель; 0 — для «Легенды» и скрытия счётчика */
  progress_target: number;
};

function clamp01(n: number): number {
  if (Number.isNaN(n) || !Number.isFinite(n)) return 0;
  return Math.max(0, Math.min(1, n));
}

/** Чтобы в подписи не было 10/5 — текущее не больше цели. */
function capCurrent(current: number, target: number): number {
  if (target <= 0) return 0;
  return Math.min(current, target);
}

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
      icon_key: 'calender-dynamic-color',
      earned: s.created_events_count >= 1,
      progress: clamp01(s.created_events_count / 1),
      progress_current: capCurrent(s.created_events_count, 1),
      progress_target: 1,
    },
    {
      id: 'organizer',
      title: 'Организатор',
      description: 'Создать 5 встреч.',
      icon_key: 'hash-dynamic-color',
      earned: s.created_events_count >= 5,
      progress: clamp01(s.created_events_count / 5),
      progress_current: capCurrent(s.created_events_count, 5),
      progress_target: 5,
    },
    {
      id: 'guest',
      title: 'В гостях',
      description:
        'Отметиться «Приду» хотя бы на одной чужой встрече (не на своей как организатор).',
      icon_key: 'takeaway-cup-dynamic-color',
      earned: s.events_i_going_as_guest_count >= 1,
      progress: clamp01(s.events_i_going_as_guest_count / 1),
      progress_current: capCurrent(s.events_i_going_as_guest_count, 1),
      progress_target: 1,
    },
    {
      id: 'social',
      title: 'На виду',
      description: 'Получить первого подписчика.',
      icon_key: 'minecraft-dynamic-color',
      earned: s.followers_count >= 1,
      progress: clamp01(s.followers_count / 1),
      progress_current: capCurrent(s.followers_count, 1),
      progress_target: 1,
    },
    {
      id: 'crowd_pleaser',
      title: 'Сбор народа',
      description:
        'Суммарно 10+ отметок «Приду» от других участников на ваших встречах (ваша не учитывается).',
      icon_key: 'crow-dynamic-color',
      earned: s.total_going_to_my_events_count >= 10,
      progress: clamp01(s.total_going_to_my_events_count / 10),
      progress_current: capCurrent(s.total_going_to_my_events_count, 10),
      progress_target: 10,
    },
    {
      id: 'legend',
      title: 'Легенда (скоро)',
      description: 'Секретное достижение — скоро добавим условие.',
      icon_key: 'trophy-dynamic-color',
      earned: false,
      progress: 0,
      progress_current: 0,
      progress_target: 0,
    },
  ];
  return list;
}
