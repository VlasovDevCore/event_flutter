-- Создаем таблицу новостей
CREATE TABLE IF NOT EXISTS news (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    is_published BOOLEAN DEFAULT true,
    view_count INTEGER DEFAULT 0
);

-- Создаем индексы для оптимизации запросов
CREATE INDEX IF NOT EXISTS idx_news_created_at ON news(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_news_is_published ON news(is_published);
CREATE INDEX IF NOT EXISTS idx_news_created_by ON news(created_by);

-- Создаем триггер для автоматического обновления updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_news_updated_at 
    BEFORE UPDATE ON news 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Добавляем комментарии к таблице и полям
COMMENT ON TABLE news IS 'Таблица новостей приложения';
COMMENT ON COLUMN news.id IS 'Уникальный идентификатор новости';
COMMENT ON COLUMN news.title IS 'Заголовок новости';
COMMENT ON COLUMN news.description IS 'Полное описание новости';
COMMENT ON COLUMN news.image_url IS 'URL изображения новости';
COMMENT ON COLUMN news.created_at IS 'Дата создания новости';
COMMENT ON COLUMN news.updated_at IS 'Дата последнего обновления';
COMMENT ON COLUMN news.created_by IS 'ID пользователя, создавшего новость';
COMMENT ON COLUMN news.is_published IS 'Флаг публикации новости';
COMMENT ON COLUMN news.view_count IS 'Количество просмотров';

-- Вставляем тестовые данные
INSERT INTO news (title, description, image_url, is_published) VALUES
(
    'Новое обновление приложения',
    'Мы добавили возможность создавать групповые чаты, улучшили производительность и исправили множество ошибок. Обновляйтесь скорее!',
    'https://i.pinimg.com/736x/1d/40/42/1d40421ba59e8c8ed34c579b840c944c.jpg',
    true
),
(
    'Конкурс на лучшее событие месяца',
    'Примите участие в конкурсе и выиграйте призы! Создайте самое интересное событие и получите возможность выиграть ценные подарки от наших партнеров.',
    'https://picsum.photos/id/20/400/200',
    true
),
(
    'Новые возможности карты',
    'Теперь вы можете видеть кластеры событий и быстрее находить интересные мероприятия рядом с вами. Мы также добавили улучшенную навигацию.',
    'https://picsum.photos/id/30/400/200',
    true
),
(
    'Друзья и подписчики',
    'Теперь вы можете следить за активностью друзей и получать уведомления о новых событиях. Добавляйте друзей и создавайте совместные мероприятия!',
    NULL,
    true
);

-- Создаем представление для списка новостей с дополнительной информацией
CREATE OR REPLACE VIEW news_list AS
SELECT 
    n.id,
    n.title,
    n.description,
    n.image_url,
    n.created_at,
    u.display_name as author_name,
    u.email as author_email
FROM news n
LEFT JOIN users u ON n.created_by = u.id
WHERE n.is_published = true
ORDER BY n.created_at DESC;


CREATE TABLE viewed_news (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  news_id UUID NOT NULL REFERENCES news(id) ON DELETE CASCADE,
  viewed_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, news_id)
);
