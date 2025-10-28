-- phpMyAdmin SQL Dump
-- version 5.2.2
-- https://www.phpmyadmin.net/
--
-- Host: localhost
-- Generation Time: Oct 01, 2025 at 07:05 PM
-- Server version: 5.7.43-log
-- PHP Version: 8.3.3

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `travel`
--

-- --------------------------------------------------------

--
-- Table structure for table `albums`
--

CREATE TABLE `albums` (
  `id` int(11) NOT NULL,
  `owner_id` int(11) NOT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `cover_photo_id` int(11) DEFAULT NULL,
  `is_public` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `albums`
--

INSERT INTO `albums` (`id`, `owner_id`, `title`, `description`, `cover_photo_id`, `is_public`, `created_at`, `updated_at`) VALUES
(23, 7, 'Топ 10 красивых мест', 'Я собрал все красивые места планеты. Оцениваете и планируйте путешествие', 143, 1, '2025-09-16 18:19:45', '2025-09-16 18:19:45'),
(27, 20, 'кей вест', 'Прикольный остров', 154, 1, '2025-09-28 02:26:15', '2025-09-28 02:26:15'),
(28, 20, 'кей вест', 'ароллпмл', 158, 1, '2025-09-29 16:26:05', '2025-09-29 16:26:05'),
(29, 20, 'formula 1 seazon 2026', '', 160, 1, '2025-09-30 15:08:45', '2025-09-30 15:08:45'),
(30, 5, 'hnkj', 'jknj', 165, 1, '2025-09-30 21:09:43', '2025-09-30 21:09:43');

-- --------------------------------------------------------

--
-- Table structure for table `album_comments`
--

CREATE TABLE `album_comments` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `album_id` int(11) NOT NULL,
  `comment` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `album_covers`
--

CREATE TABLE `album_covers` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `file_path` varchar(255) NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `album_covers`
--

INSERT INTO `album_covers` (`id`, `user_id`, `file_path`, `created_at`) VALUES
(1, 5, '/travel/album/covers/5_cover_68c3f1e62314c_1757671910.jpg', '2025-09-12 10:11:50');

-- --------------------------------------------------------

--
-- Table structure for table `album_favorites`
--

CREATE TABLE `album_favorites` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `album_id` int(11) NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `album_favorites`
--

INSERT INTO `album_favorites` (`id`, `user_id`, `album_id`, `created_at`) VALUES
(50, 5, 23, '2025-09-19 18:27:27');

-- --------------------------------------------------------

--
-- Table structure for table `album_likes`
--

CREATE TABLE `album_likes` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `album_id` int(11) NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `album_likes`
--

INSERT INTO `album_likes` (`id`, `user_id`, `album_id`, `created_at`) VALUES
(31, 20, 23, '2025-09-20 23:10:12'),
(32, 7, 27, '2025-09-28 08:25:45');

-- --------------------------------------------------------

--
-- Table structure for table `album_photos`
--

CREATE TABLE `album_photos` (
  `id` int(11) NOT NULL,
  `album_id` int(11) NOT NULL,
  `photo_id` int(11) NOT NULL,
  `position` int(11) NOT NULL DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `album_photos`
--

INSERT INTO `album_photos` (`id`, `album_id`, `photo_id`, `position`, `created_at`) VALUES
(41, 23, 138, 0, '2025-09-16 18:19:45'),
(42, 23, 136, 1, '2025-09-16 18:19:45'),
(45, 23, 147, 2, '2025-09-24 20:10:53'),
(47, 27, 152, 1, '2025-09-28 02:26:15'),
(48, 27, 151, 2, '2025-09-28 02:26:15'),
(49, 27, 150, 3, '2025-09-28 02:26:15'),
(50, 28, 156, 0, '2025-09-29 16:26:05'),
(51, 28, 152, 1, '2025-09-29 16:26:05'),
(52, 28, 151, 2, '2025-09-29 16:26:05'),
(53, 28, 150, 3, '2025-09-29 16:26:05'),
(54, 29, 161, 0, '2025-09-30 15:08:45'),
(55, 30, 148, 0, '2025-09-30 21:09:43');

-- --------------------------------------------------------

--
-- Table structure for table `comments`
--

CREATE TABLE `comments` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `photo_id` int(11) NOT NULL,
  `comment` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `comments`
--

INSERT INTO `comments` (`id`, `user_id`, `photo_id`, `comment`, `created_at`, `updated_at`) VALUES
(17, 20, 145, 'работает', '2025-09-20 23:08:39', '2025-09-20 23:08:39'),
(18, 20, 145, 'вроде', '2025-09-20 23:08:52', '2025-09-20 23:08:52'),
(19, 20, 146, 'комментарий', '2025-09-20 23:42:26', '2025-09-20 23:42:26'),
(20, 20, 151, 'аполрпарол', '2025-09-29 15:43:22', '2025-09-29 15:43:22'),
(21, 20, 138, 'апоорикпроььт', '2025-09-29 15:44:18', '2025-09-29 15:44:18'),
(22, 20, 159, 'ероормио', '2025-09-29 16:29:15', '2025-09-29 16:29:15'),
(23, 5, 161, 'rtbberbert', '2025-09-30 20:25:27', '2025-09-30 20:25:27'),
(24, 5, 156, 'hbjk', '2025-09-30 20:29:20', '2025-09-30 20:29:20'),
(25, 5, 152, 'bjhjnkkjb', '2025-09-30 20:33:36', '2025-09-30 20:33:36'),
(26, 5, 152, 'bjhnjlmk,', '2025-09-30 20:37:11', '2025-09-30 20:37:11'),
(27, 5, 161, 'gbwrtbwrtbwt', '2025-09-30 20:42:54', '2025-09-30 20:42:54');

-- --------------------------------------------------------

--
-- Table structure for table `commercial_favorites`
--

CREATE TABLE `commercial_favorites` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `commercial_post_id` int(11) NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `commercial_favorites`
--

INSERT INTO `commercial_favorites` (`id`, `user_id`, `commercial_post_id`, `created_at`) VALUES
(6, 20, 26, '2025-09-20 23:12:52'),
(7, 20, 25, '2025-09-20 23:12:53'),
(8, 20, 24, '2025-09-20 23:13:38');

-- --------------------------------------------------------

--
-- Table structure for table `commercial_posts`
--

CREATE TABLE `commercial_posts` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `album_id` int(11) DEFAULT NULL,
  `photo_id` int(11) DEFAULT NULL,
  `type` enum('album','photo','standalone') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'album',
  `title` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `image_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `price` decimal(10,2) DEFAULT NULL,
  `currency` varchar(3) COLLATE utf8mb4_unicode_ci DEFAULT 'USD',
  `contact_info` text COLLATE utf8mb4_unicode_ci,
  `latitude` decimal(10,7) DEFAULT NULL,
  `longitude` decimal(10,7) DEFAULT NULL,
  `location_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Коммерческие посты: могут быть привязаны к альбомам, отдельным фото или быть standalone';

--
-- Dumping data for table `commercial_posts`
--

INSERT INTO `commercial_posts` (`id`, `user_id`, `album_id`, `photo_id`, `type`, `title`, `description`, `image_url`, `price`, `currency`, `contact_info`, `latitude`, `longitude`, `location_name`, `is_active`, `created_at`, `updated_at`) VALUES
(24, 7, 23, NULL, 'album', 'Экскурсии на Эйфелеву башню', 'Приглашаем посетить нашу экскурсию на Эйфелеву башню. Без очередей. Цена за человека 10$. Пишите или звоните: 89000000000', '/travel/uploads/commercial_images/commercial_7_1758048738_0.jpg', NULL, 'USD', NULL, NULL, NULL, NULL, 1, '2025-09-16 18:52:18', '2025-09-16 18:52:18'),
(25, 7, 23, NULL, 'album', 'Битва с гладиаторами', 'Устройте настоящуюю битву с гладиаторами в легендарном коллизее. Полное обмундирование и защита. Безопасно и интересно.\nМы находимся справа от входа', '/travel/uploads/commercial_images/commercial_7_1758048830_0.jpg', NULL, 'USD', NULL, NULL, NULL, NULL, 1, '2025-09-16 18:53:50', '2025-09-16 18:53:50'),
(26, 7, 23, NULL, 'album', 'Церковь Святого Евгения', 'Паломничество к святому Евгению. Хотите принять христианство в знаменитой церкви? Приходите, мы вас проводим', '/travel/uploads/commercial_images/commercial_7_1758048983_0.jpg', NULL, 'USD', NULL, NULL, NULL, NULL, 1, '2025-09-16 18:56:23', '2025-09-16 18:56:23'),
(37, 5, NULL, 138, 'photo', 'укиукиук', 'укицукеиуке', NULL, NULL, 'USD', NULL, 37.4219983, -122.0840000, 'Current Location', 1, '2025-09-19 19:25:02', '2025-09-19 19:25:18'),
(38, 5, 30, 136, 'standalone', 'авпр', 'рикери', NULL, NULL, 'USD', NULL, 37.4219983, -122.0840000, '1500 Charleston Road, Mountain View, California 94043, United States', 1, '2025-09-19 20:00:29', '2025-10-01 10:57:21'),
(41, 20, NULL, NULL, 'standalone', 'диснейленд', 'Веселые дисней лэнд', NULL, NULL, 'USD', NULL, 28.3560841, -81.5626096, '501 Cypress Drive, Orlando, Florida 32830, United States', 1, '2025-09-29 16:18:24', '2025-09-29 16:18:24');

-- --------------------------------------------------------

--
-- Table structure for table `commercial_post_albums`
--

CREATE TABLE `commercial_post_albums` (
  `id` int(11) NOT NULL,
  `commercial_post_id` int(11) NOT NULL,
  `album_id` int(11) NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `commercial_post_albums`
--

INSERT INTO `commercial_post_albums` (`id`, `commercial_post_id`, `album_id`, `created_at`) VALUES
(1, 24, 23, '2025-10-01 10:49:35'),
(2, 25, 23, '2025-10-01 10:49:35'),
(3, 26, 23, '2025-10-01 10:49:35'),
(4, 38, 30, '2025-10-01 10:49:35');

-- --------------------------------------------------------

--
-- Table structure for table `commercial_post_favorites`
--

CREATE TABLE `commercial_post_favorites` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `commercial_post_id` int(11) NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `commercial_post_images`
--

CREATE TABLE `commercial_post_images` (
  `id` int(11) NOT NULL,
  `commercial_post_id` int(11) NOT NULL,
  `image_url` varchar(255) NOT NULL,
  `image_order` int(11) DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Multiple images for commercial posts with ordering support';

--
-- Dumping data for table `commercial_post_images`
--

INSERT INTO `commercial_post_images` (`id`, `commercial_post_id`, `image_url`, `image_order`, `created_at`) VALUES
(2, 24, '/travel/uploads/commercial_images/commercial_7_1758048738_0.jpg', 0, '2025-09-16 18:52:18'),
(3, 25, '/travel/uploads/commercial_images/commercial_7_1758048830_0.jpg', 0, '2025-09-16 18:53:50'),
(4, 26, '/travel/uploads/commercial_images/commercial_7_1758048983_0.jpg', 0, '2025-09-16 18:56:23'),
(12, 37, 'uploads/commercial/68cdae0e0c882_commercial_image_1758309901195_0.jpg', 0, '2025-09-19 19:25:02'),
(13, 38, 'uploads/commercial/68cdb65dca19d_commercial_image_1758312028817_0.jpg', 0, '2025-09-19 20:00:29'),
(17, 41, 'uploads/commercial/68dab1507320c_commercial_image_1759162703043_0.jpg', 0, '2025-09-29 16:18:24');

-- --------------------------------------------------------

--
-- Table structure for table `commercial_post_photos`
--

CREATE TABLE `commercial_post_photos` (
  `id` int(11) NOT NULL,
  `commercial_post_id` int(11) NOT NULL,
  `photo_id` int(11) NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `commercial_post_photos`
--

INSERT INTO `commercial_post_photos` (`id`, `commercial_post_id`, `photo_id`, `created_at`) VALUES
(1, 38, 136, '2025-10-01 10:49:35'),
(2, 37, 138, '2025-10-01 10:49:35'),
(4, 38, 161, '2025-10-01 10:57:21');

-- --------------------------------------------------------

--
-- Table structure for table `favorites`
--

CREATE TABLE `favorites` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `photo_id` int(11) NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `favorites`
--

INSERT INTO `favorites` (`id`, `user_id`, `photo_id`, `created_at`) VALUES
(59, 20, 136, '2025-09-20 23:09:12'),
(60, 20, 138, '2025-09-20 23:09:16');

-- --------------------------------------------------------

--
-- Table structure for table `follows`
--

CREATE TABLE `follows` (
  `id` int(11) NOT NULL,
  `follower_id` int(11) NOT NULL,
  `followed_id` int(11) NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `follows`
--

INSERT INTO `follows` (`id`, `follower_id`, `followed_id`, `created_at`) VALUES
(2, 7, 5, '2025-03-31 18:49:36'),
(4, 6, 7, '2025-04-08 12:52:51'),
(5, 6, 5, '2025-04-08 12:53:45'),
(9, 6, 20, '2025-04-12 16:05:38'),
(25, 7, 20, '2025-08-13 18:30:48'),
(27, 20, 6, '2025-08-24 12:30:28'),
(28, 7, 6, '2025-08-24 18:29:20'),
(29, 5, 7, '2025-09-04 07:20:12'),
(30, 5, 20, '2025-09-04 12:48:54'),
(31, 20, 7, '2025-09-27 14:38:38');

-- --------------------------------------------------------

--
-- Table structure for table `likes`
--

CREATE TABLE `likes` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `photo_id` int(11) NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `likes`
--

INSERT INTO `likes` (`id`, `user_id`, `photo_id`, `created_at`) VALUES
(41, 20, 136, '2025-09-20 23:09:14'),
(43, 20, 138, '2025-09-29 15:43:42');

-- --------------------------------------------------------

--
-- Table structure for table `locations`
--

CREATE TABLE `locations` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `latitude` decimal(10,8) NOT NULL,
  `longitude` decimal(11,8) NOT NULL,
  `address` text COLLATE utf8mb4_unicode_ci,
  `city` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `country` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `locations`
--

INSERT INTO `locations` (`id`, `user_id`, `title`, `description`, `latitude`, `longitude`, `address`, `city`, `country`, `created_at`, `updated_at`) VALUES
(78, 7, 'Колизей, 00184 Рим Рим, Италия', 'Колизей (Амфитеатр Флавиев) — это грандиозный эллиптический амфитеатр в Риме, построенный между 71 и 80 годами н. э. Он служил местом проведения гладиаторских боев, звериных травль, публичных казней и даже шуточных морских сражений. Это крупнейший древний амфитеатр в мире, способный вместить до 80 тысяч зрителей, и одно из самых известных сооружений Древнего Рима, являющееся символом столицы Италии.', 41.89090600, 12.49274400, '', NULL, NULL, '2025-09-15 17:29:38', '2025-09-15 19:58:49'),
(80, 7, 'Paris, France', 'Э́йфелева ба́шня (фр. tour Eiffel, МФА: [tu.ʁ‿ɛ.fɛl]) — металлическая башня в центре Парижа, самая узнаваемая его архитектурная достопримечательность. Названа в честь главного конструктора Гюстава Эйфеля; сам Эйфель называл её просто «300-метровая башня» (tour de 300 mètres).', 48.85349500, 2.34839200, '', NULL, NULL, '2025-09-15 20:07:11', '2025-09-15 20:07:11'),
(83, 7, 'Russia, Penza, Penza, Pervomayskiy, 440046, ulitsa Mira 44а', 'иаукбшл', 53.18813690, 44.97670530, '', NULL, NULL, '2025-09-24 20:10:37', '2025-09-24 20:10:37'),
(84, 5, '1500 Charleston Road, Mountain View, California 94043, United States', 'test', 37.42199830, -122.08400000, '', NULL, NULL, '2025-09-26 18:50:22', '2025-09-26 18:50:22'),
(86, 20, 'Ernest Hemingway Home', '', 24.55124000, -81.80055000, '', NULL, NULL, '2025-09-28 01:59:51', '2025-09-28 01:59:51'),
(87, 20, 'Truman Little White House', 'Маленький белый дом', 24.55633000, -81.80690000, '', NULL, NULL, '2025-09-28 02:05:28', '2025-09-28 02:05:28'),
(88, 20, 'End US 1 (south ) and Mile 0', '', 24.55528347, -81.80391166, '', NULL, NULL, '2025-09-28 02:18:58', '2025-09-28 02:18:58'),
(89, 20, 'Sloppy Joe\'s Bar', 'Живая музыка и хорошая атмосфера', 24.55908400, -81.80497100, '', NULL, NULL, '2025-09-28 02:21:59', '2025-09-29 15:30:16'),
(90, 20, 'Мельбурн, Виктория, Австралия', '', -37.81419800, 144.96333000, '', NULL, NULL, '2025-09-30 15:08:27', '2025-09-30 15:08:27');

-- --------------------------------------------------------

--
-- Table structure for table `photos`
--

CREATE TABLE `photos` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `location_id` int(11) DEFAULT NULL,
  `file_path` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `uuid` varchar(36) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `position` int(11) DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `photos`
--

INSERT INTO `photos` (`id`, `user_id`, `location_id`, `file_path`, `title`, `description`, `created_at`, `updated_at`, `uuid`, `position`) VALUES
(136, 7, 78, '/travel/uploads/location_images/7_78_68c84d02a5ea3_1757957378.jpg', NULL, NULL, '2025-09-15 19:58:49', '2025-09-15 19:58:49', NULL, 0),
(137, 7, 78, '/travel/uploads/location_images/7_78_68c84d032805e_1757957379.jpg', NULL, NULL, '2025-09-15 19:58:49', '2025-09-15 19:58:49', NULL, 1),
(138, 7, 80, '/travel/uploads/location_images/7_80_68c871f000964_1757966832.jpg', 'Эйфелева Башня', 'Э́йфелева ба́шня (фр. tour Eiffel, МФА: [tu.ʁ‿ɛ.fɛl]) — металлическая башня в центре Парижа, самая узнаваемая его архитектурная достопримечательность. Названа в честь главного конструктора Гюстава Эйфеля; сам Эйфель называл её просто «300-метровая башня» (tour de 300 mètres).', '2025-09-15 20:07:12', '2025-09-15 20:07:12', NULL, 0),
(139, 7, 80, '/travel/uploads/location_images/7_80_68c871f084123_1757966832.jpg', 'Эйфелева Башня', 'Э́йфелева ба́шня (фр. tour Eiffel, МФА: [tu.ʁ‿ɛ.fɛl]) — металлическая башня в центре Парижа, самая узнаваемая его архитектурная достопримечательность. Названа в честь главного конструктора Гюстава Эйфеля; сам Эйфель называл её просто «300-метровая башня» (tour de 300 mètres).', '2025-09-15 20:07:12', '2025-09-15 20:07:12', NULL, 1),
(140, 7, 80, '/travel/uploads/location_images/7_80_68c871f13a78d_1757966833.jpg', 'Эйфелева Башня', 'Э́йфелева ба́шня (фр. tour Eiffel, МФА: [tu.ʁ‿ɛ.fɛl]) — металлическая башня в центре Парижа, самая узнаваемая его архитектурная достопримечательность. Названа в честь главного конструктора Гюстава Эйфеля; сам Эйфель называл её просто «300-метровая башня» (tour de 300 mètres).', '2025-09-15 20:07:13', '2025-09-15 20:07:13', NULL, 2),
(141, 7, 80, '/travel/uploads/location_images/7_80_68c871f1bc4e9_1757966833.jpg', 'Эйфелева Башня', 'Э́йфелева ба́шня (фр. tour Eiffel, МФА: [tu.ʁ‿ɛ.fɛl]) — металлическая башня в центре Парижа, самая узнаваемая его архитектурная достопримечательность. Названа в честь главного конструктора Гюстава Эйфеля; сам Эйфель называл её просто «300-метровая башня» (tour de 300 mètres).', '2025-09-15 20:07:13', '2025-09-15 20:07:13', NULL, 3),
(143, 7, NULL, '/travel/uploads/location_images/7_album_cover_68c9aa385bdf9_1758046776.jpg', 'Album Cover', 'Uploaded as album cover', '2025-09-16 18:19:36', '2025-09-16 18:19:36', NULL, 0),
(145, 20, NULL, 'temp_photo.jpg', NULL, NULL, '2025-09-20 23:08:39', '2025-09-20 23:08:39', 'commercial_38', 0),
(146, 20, NULL, 'temp_photo.jpg', NULL, NULL, '2025-09-20 23:42:26', '2025-09-20 23:42:26', 'commercial_24', 0),
(147, 7, 83, '/travel/uploads/location_images/7_83_68d4503f5d146_1758744639.jpg', 'мьббб', 'иаукбшл', '2025-09-24 20:10:39', '2025-09-24 20:10:39', NULL, 0),
(148, 5, 84, '/travel/uploads/location_images/5_84_68d6e06eed097_1758912622.jpg', 'test', 'test', '2025-09-26 18:50:22', '2025-09-26 18:50:22', NULL, 0),
(150, 20, 86, '/travel/uploads/location_images/20_86_68d896998d97d_1759024793.jpg', 'дом хемингуэя', '', '2025-09-28 01:59:53', '2025-09-28 01:59:53', NULL, 0),
(151, 20, 87, '/travel/uploads/location_images/20_87_68d897ea143a7_1759025130.jpg', 'маленький белый дом', 'Маленький белый дом', '2025-09-28 02:05:30', '2025-09-28 02:05:30', NULL, 0),
(152, 20, 88, '/travel/uploads/location_images/20_88_68d89b141e1e6_1759025940.jpg', 'нулевая точка us 1', '', '2025-09-28 02:19:00', '2025-09-28 02:19:00', NULL, 0),
(154, 20, NULL, '/travel/uploads/location_images/20_album_cover_68d89c8786319_1759026311.png', 'Album Cover', 'Uploaded as album cover', '2025-09-28 02:25:11', '2025-09-28 02:25:11', NULL, 0),
(156, 20, 89, '/travel/uploads/location_images/20_89_68d89bc87af55_1759026120.jpg', 'прикольный бар', 'Живая музыка и хорошая атмосфера', '2025-09-29 15:30:16', '2025-09-29 15:30:16', NULL, 0),
(157, 20, 89, '/travel/uploads/location_images/20_89_68daa607144ec_1759159815.png', 'прикольный бар', 'Живая музыка и хорошая атмосфера', '2025-09-29 15:30:16', '2025-09-29 15:30:16', NULL, 1),
(158, 20, NULL, '/travel/uploads/location_images/20_album_cover_68dab2a8b109a_1759163048.jpg', 'Album Cover', 'Uploaded as album cover', '2025-09-29 16:24:08', '2025-09-29 16:24:08', NULL, 0),
(159, 20, NULL, 'temp_photo.jpg', NULL, NULL, '2025-09-29 16:29:15', '2025-09-29 16:29:15', 'commercial_26', 0),
(160, 20, NULL, '/travel/uploads/location_images/20_album_cover_68dbf05e8a98a_1759244382.png', 'Album Cover', 'Uploaded as album cover', '2025-09-30 14:59:42', '2025-09-30 14:59:42', NULL, 0),
(161, 20, 90, '/travel/uploads/location_images/20_90_68dbf26dc226f_1759244909.jpg', 'March 6-8 австралия мельбурн', '', '2025-09-30 15:08:29', '2025-09-30 15:08:29', NULL, 0),
(162, 20, 90, '/travel/uploads/location_images/20_90_68dbf27020888_1759244912.webp', 'March 6-8 австралия мельбурн', '', '2025-09-30 15:08:32', '2025-09-30 15:08:32', NULL, 1),
(163, 20, 90, '/travel/uploads/location_images/20_90_68dbf2723021c_1759244914.jpg', 'March 6-8 австралия мельбурн', '', '2025-09-30 15:08:34', '2025-09-30 15:08:34', NULL, 2),
(164, 20, 90, '/travel/uploads/location_images/20_90_68dbf274033fa_1759244916.jpg', 'March 6-8 австралия мельбурн', '', '2025-09-30 15:08:36', '2025-09-30 15:08:36', NULL, 3),
(165, 5, NULL, '/travel/uploads/location_images/5_album_cover_68dc470f84b48_1759266575.jpg', 'Album Cover', 'Uploaded as album cover', '2025-09-30 21:09:35', '2025-09-30 21:09:35', NULL, 0);

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `id` int(11) NOT NULL,
  `google_id` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `apple_id` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `first_name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `last_name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `profile_image_url` text COLLATE utf8mb4_unicode_ci,
  `birthday` date DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `google_id`, `apple_id`, `email`, `first_name`, `last_name`, `profile_image_url`, `birthday`, `created_at`, `updated_at`) VALUES
(5, 'access_19a9bf2eb41763e62456a6f390176620', NULL, 'millionreklamy2@gmail.com', 'Same', 'Video', 'https://lh3.googleusercontent.com/a/ACg8ocJ5FwSt7itCLKayUB975Vx1u_hRRs1ECH4dTMN_cdT0p5R57P0', '2007-04-04', '2025-03-28 19:23:13', '2025-09-19 18:12:11'),
(6, 'access_65e0091d485da277f1819e765c8a2b29', 'apple_67139cbbb5d4551f33bd0c7df4b1780d', 'zhulikoff159@gmail.com', '16', 'Столик', 'https://lh3.googleusercontent.com/a/ACg8ocK93ylX-N8CKELzFhWULTED1cvcJrDwIA-MB-JAzZS6vYIK5ww', NULL, '2025-03-28 19:25:14', '2025-09-15 17:23:02'),
(7, 'access_84cf5380f7697bf89441c36a81d3bd88', NULL, 'millionreklamy@gmail.com', 'Web', 'Studio', '/travel/uploads/profile_images/7_67e70a468784a_1743194694.jpg', NULL, '2025-03-28 20:43:09', '2025-09-28 08:33:14'),
(11, NULL, 'apple_6e7fc7de7663965e68fe0a242066b48b', 'noemail_6e7fc7de76@apple.user', '', '', '', NULL, '2025-04-07 14:08:38', '2025-04-07 14:08:38'),
(12, NULL, 'apple_ba0d9ab476fa3a0f2910864f59be7614', 'noemail_ba0d9ab476@apple.user', '', '', '', NULL, '2025-04-07 14:11:26', '2025-04-07 14:11:26'),
(13, NULL, 'apple_0e2be7e5203e4e6255d1603f332ed8f7', 'noemail_0e2be7e520@apple.user', '', '', '', NULL, '2025-04-07 14:17:32', '2025-04-07 14:17:32'),
(14, NULL, 'apple_4d05ed5fd14bd51befe322ed6d28589d', 'noemail_4d05ed5fd1@apple.user', '', '', '', NULL, '2025-04-07 14:18:02', '2025-04-07 14:18:02'),
(15, NULL, 'apple_45ac1875c980b2ed089b397fcd23f1f2', 'noemail_45ac1875c9@apple.user', '', '', '', NULL, '2025-04-07 14:31:17', '2025-04-07 14:31:17'),
(16, NULL, 'apple_a1eb1867af40e62afe385b2dcaf96142', 'noemail_a1eb1867af@apple.user', '', '', '', NULL, '2025-04-07 14:48:05', '2025-04-07 14:48:05'),
(17, NULL, 'apple_2c219ed3f37bd51c556a80ec9fe2ebfc', 'noemail_2c219ed3f3@apple.user', '', '', '', NULL, '2025-04-07 14:50:56', '2025-04-07 14:50:56'),
(18, NULL, 'apple_13c7dec705c0cebeed609b51409a3ee7', 'noemail_13c7dec705@apple.user', '', '', '', NULL, '2025-04-09 08:13:32', '2025-04-09 08:13:32'),
(19, NULL, 'apple_074025e229b32c9e3b96a1d1d45480b2', 'noemail_074025e229@apple.user', '', '', '', NULL, '2025-04-09 11:36:05', '2025-04-09 11:36:05'),
(20, 'access_d9bf603e64781ccd12bf4a7584176047', NULL, 'victorreb111@gmail.com', 'Victor', 'Rebrov', '/travel/uploads/profile_images/20_67f81d8fe9b3b_1744313743.jpg', NULL, '2025-04-10 13:41:26', '2025-09-29 15:14:23'),
(21, NULL, 'apple_c9c3a6c11ff979066c007273bf4ccea4', 'noemail_c9c3a6c11f@apple.user', 'Test', NULL, '/travel/uploads/profile_images/21_67f90fbf9ac12_1744375743.jpg', NULL, '2025-04-11 12:48:09', '2025-04-11 12:49:12'),
(22, NULL, 'apple_40f00d3eebb8f5ed537b61c000ee5c4e', 'noemail_40f00d3eeb@apple.user', '', '', '', NULL, '2025-04-15 08:02:44', '2025-04-15 08:02:44'),
(23, NULL, 'apple_26b5a42892d146ae0837adcf7556edfc', 'noemail_26b5a42892@apple.user', '', '', '', NULL, '2025-04-17 10:57:28', '2025-04-17 10:57:28'),
(24, NULL, 'apple_131be0b87af406671a872e544a86c540', 'noemail_131be0b87a@apple.user', '', '', '', NULL, '2025-04-21 21:17:31', '2025-04-21 21:17:31');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `albums`
--
ALTER TABLE `albums`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_albums_cover` (`cover_photo_id`),
  ADD KEY `idx_albums_owner_id` (`owner_id`),
  ADD KEY `idx_albums_is_public` (`is_public`);

--
-- Indexes for table `album_comments`
--
ALTER TABLE `album_comments`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_album_comments_user_id` (`user_id`),
  ADD KEY `idx_album_comments_album_id` (`album_id`);

--
-- Indexes for table `album_covers`
--
ALTER TABLE `album_covers`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_user_id` (`user_id`);

--
-- Indexes for table `album_favorites`
--
ALTER TABLE `album_favorites`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_album_favorite` (`user_id`,`album_id`),
  ADD KEY `idx_album_favorites_user_id` (`user_id`),
  ADD KEY `idx_album_favorites_album_id` (`album_id`);

--
-- Indexes for table `album_likes`
--
ALTER TABLE `album_likes`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_album_like` (`user_id`,`album_id`),
  ADD KEY `idx_album_likes_user_id` (`user_id`),
  ADD KEY `idx_album_likes_album_id` (`album_id`);

--
-- Indexes for table `album_photos`
--
ALTER TABLE `album_photos`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_album_photo` (`album_id`,`photo_id`),
  ADD KEY `idx_album_photos_album_id` (`album_id`),
  ADD KEY `idx_album_photos_photo_id` (`photo_id`);

--
-- Indexes for table `comments`
--
ALTER TABLE `comments`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_comments_user_id` (`user_id`),
  ADD KEY `idx_comments_photo_id` (`photo_id`);

--
-- Indexes for table `commercial_favorites`
--
ALTER TABLE `commercial_favorites`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_commercial_favorite` (`user_id`,`commercial_post_id`),
  ADD KEY `idx_cf_user_id` (`user_id`),
  ADD KEY `idx_cf_post_id` (`commercial_post_id`);

--
-- Indexes for table `commercial_posts`
--
ALTER TABLE `commercial_posts`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_commercial_posts_user_id` (`user_id`),
  ADD KEY `idx_commercial_posts_album_id` (`album_id`),
  ADD KEY `idx_commercial_posts_is_active` (`is_active`),
  ADD KEY `idx_commercial_posts_location` (`latitude`,`longitude`),
  ADD KEY `idx_commercial_posts_location_name` (`location_name`),
  ADD KEY `idx_commercial_posts_photo_id` (`photo_id`),
  ADD KEY `idx_commercial_posts_type_album` (`type`,`album_id`),
  ADD KEY `idx_commercial_posts_type_photo` (`type`,`photo_id`),
  ADD KEY `idx_commercial_posts_type_user` (`type`,`user_id`),
  ADD KEY `idx_commercial_posts_active_type` (`is_active`,`type`);

--
-- Indexes for table `commercial_post_albums`
--
ALTER TABLE `commercial_post_albums`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_post_album` (`commercial_post_id`,`album_id`),
  ADD KEY `idx_commercial_post_id` (`commercial_post_id`),
  ADD KEY `idx_album_id` (`album_id`);

--
-- Indexes for table `commercial_post_favorites`
--
ALTER TABLE `commercial_post_favorites`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_commercial_post_favorite` (`user_id`,`commercial_post_id`),
  ADD KEY `idx_commercial_post_favorites_user_id` (`user_id`),
  ADD KEY `idx_commercial_post_favorites_post_id` (`commercial_post_id`);

--
-- Indexes for table `commercial_post_images`
--
ALTER TABLE `commercial_post_images`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_commercial_post_id` (`commercial_post_id`),
  ADD KEY `idx_image_order` (`image_order`);

--
-- Indexes for table `commercial_post_photos`
--
ALTER TABLE `commercial_post_photos`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_post_photo` (`commercial_post_id`,`photo_id`),
  ADD KEY `idx_commercial_post_id` (`commercial_post_id`),
  ADD KEY `idx_photo_id` (`photo_id`);

--
-- Indexes for table `favorites`
--
ALTER TABLE `favorites`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `user_id` (`user_id`,`photo_id`),
  ADD KEY `idx_favorites_user_id` (`user_id`),
  ADD KEY `idx_favorites_photo_id` (`photo_id`);

--
-- Indexes for table `follows`
--
ALTER TABLE `follows`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `follower_id` (`follower_id`,`followed_id`),
  ADD KEY `idx_follows_follower_id` (`follower_id`),
  ADD KEY `idx_follows_followed_id` (`followed_id`);

--
-- Indexes for table `likes`
--
ALTER TABLE `likes`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `user_id` (`user_id`,`photo_id`),
  ADD KEY `idx_likes_user_id` (`user_id`),
  ADD KEY `idx_likes_photo_id` (`photo_id`);

--
-- Indexes for table `locations`
--
ALTER TABLE `locations`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_locations_user_id` (`user_id`);

--
-- Indexes for table `photos`
--
ALTER TABLE `photos`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_photos_user_id` (`user_id`),
  ADD KEY `idx_photos_location_id` (`location_id`),
  ADD KEY `idx_photos_uuid` (`uuid`),
  ADD KEY `idx_photos_position` (`position`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `email` (`email`),
  ADD UNIQUE KEY `google_id` (`google_id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `albums`
--
ALTER TABLE `albums`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=31;

--
-- AUTO_INCREMENT for table `album_comments`
--
ALTER TABLE `album_comments`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `album_covers`
--
ALTER TABLE `album_covers`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `album_favorites`
--
ALTER TABLE `album_favorites`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=52;

--
-- AUTO_INCREMENT for table `album_likes`
--
ALTER TABLE `album_likes`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=33;

--
-- AUTO_INCREMENT for table `album_photos`
--
ALTER TABLE `album_photos`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=56;

--
-- AUTO_INCREMENT for table `comments`
--
ALTER TABLE `comments`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=28;

--
-- AUTO_INCREMENT for table `commercial_favorites`
--
ALTER TABLE `commercial_favorites`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10;

--
-- AUTO_INCREMENT for table `commercial_posts`
--
ALTER TABLE `commercial_posts`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=42;

--
-- AUTO_INCREMENT for table `commercial_post_albums`
--
ALTER TABLE `commercial_post_albums`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT for table `commercial_post_favorites`
--
ALTER TABLE `commercial_post_favorites`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `commercial_post_images`
--
ALTER TABLE `commercial_post_images`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=18;

--
-- AUTO_INCREMENT for table `commercial_post_photos`
--
ALTER TABLE `commercial_post_photos`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `favorites`
--
ALTER TABLE `favorites`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=67;

--
-- AUTO_INCREMENT for table `follows`
--
ALTER TABLE `follows`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=32;

--
-- AUTO_INCREMENT for table `likes`
--
ALTER TABLE `likes`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=44;

--
-- AUTO_INCREMENT for table `locations`
--
ALTER TABLE `locations`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=92;

--
-- AUTO_INCREMENT for table `photos`
--
ALTER TABLE `photos`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=167;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=25;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `albums`
--
ALTER TABLE `albums`
  ADD CONSTRAINT `fk_albums_cover` FOREIGN KEY (`cover_photo_id`) REFERENCES `photos` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_albums_owner` FOREIGN KEY (`owner_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `album_comments`
--
ALTER TABLE `album_comments`
  ADD CONSTRAINT `fk_album_comments_album` FOREIGN KEY (`album_id`) REFERENCES `albums` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_album_comments_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `album_covers`
--
ALTER TABLE `album_covers`
  ADD CONSTRAINT `album_covers_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `album_favorites`
--
ALTER TABLE `album_favorites`
  ADD CONSTRAINT `fk_album_favorites_album` FOREIGN KEY (`album_id`) REFERENCES `albums` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_album_favorites_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `album_likes`
--
ALTER TABLE `album_likes`
  ADD CONSTRAINT `fk_album_likes_album` FOREIGN KEY (`album_id`) REFERENCES `albums` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_album_likes_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `album_photos`
--
ALTER TABLE `album_photos`
  ADD CONSTRAINT `fk_album_photos_album` FOREIGN KEY (`album_id`) REFERENCES `albums` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_album_photos_photo` FOREIGN KEY (`photo_id`) REFERENCES `photos` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `comments`
--
ALTER TABLE `comments`
  ADD CONSTRAINT `comments_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `comments_ibfk_2` FOREIGN KEY (`photo_id`) REFERENCES `photos` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `commercial_favorites`
--
ALTER TABLE `commercial_favorites`
  ADD CONSTRAINT `fk_cf_post` FOREIGN KEY (`commercial_post_id`) REFERENCES `commercial_posts` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_cf_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `commercial_posts`
--
ALTER TABLE `commercial_posts`
  ADD CONSTRAINT `fk_commercial_posts_album` FOREIGN KEY (`album_id`) REFERENCES `albums` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_commercial_posts_photo` FOREIGN KEY (`photo_id`) REFERENCES `photos` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_commercial_posts_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `commercial_post_albums`
--
ALTER TABLE `commercial_post_albums`
  ADD CONSTRAINT `commercial_post_albums_ibfk_1` FOREIGN KEY (`commercial_post_id`) REFERENCES `commercial_posts` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `commercial_post_albums_ibfk_2` FOREIGN KEY (`album_id`) REFERENCES `albums` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `commercial_post_favorites`
--
ALTER TABLE `commercial_post_favorites`
  ADD CONSTRAINT `fk_commercial_post_favorites_post` FOREIGN KEY (`commercial_post_id`) REFERENCES `commercial_posts` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_commercial_post_favorites_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `commercial_post_images`
--
ALTER TABLE `commercial_post_images`
  ADD CONSTRAINT `commercial_post_images_ibfk_1` FOREIGN KEY (`commercial_post_id`) REFERENCES `commercial_posts` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `commercial_post_photos`
--
ALTER TABLE `commercial_post_photos`
  ADD CONSTRAINT `commercial_post_photos_ibfk_1` FOREIGN KEY (`commercial_post_id`) REFERENCES `commercial_posts` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `commercial_post_photos_ibfk_2` FOREIGN KEY (`photo_id`) REFERENCES `photos` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `favorites`
--
ALTER TABLE `favorites`
  ADD CONSTRAINT `favorites_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `favorites_ibfk_2` FOREIGN KEY (`photo_id`) REFERENCES `photos` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `follows`
--
ALTER TABLE `follows`
  ADD CONSTRAINT `follows_ibfk_1` FOREIGN KEY (`follower_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `follows_ibfk_2` FOREIGN KEY (`followed_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `likes`
--
ALTER TABLE `likes`
  ADD CONSTRAINT `likes_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `likes_ibfk_2` FOREIGN KEY (`photo_id`) REFERENCES `photos` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `locations`
--
ALTER TABLE `locations`
  ADD CONSTRAINT `locations_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `photos`
--
ALTER TABLE `photos`
  ADD CONSTRAINT `photos_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `photos_ibfk_2` FOREIGN KEY (`location_id`) REFERENCES `locations` (`id`) ON DELETE SET NULL;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
