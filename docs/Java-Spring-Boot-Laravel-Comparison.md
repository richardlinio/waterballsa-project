# Laravel (PHP) vs. Spring Boot (Java) 生態系快速對照

| 概念 / 分類 (Concept / Category)  | Laravel (PHP)                               | Spring Boot (Java)                                   | 備註 (Notes)                                                                                      |
| :-------------------------------- | :------------------------------------------ | :--------------------------------------------------- | :------------------------------------------------------------------------------------------------ |
| **語言 (Language)**               | PHP (直譯式、動態型別)                      | Java (編譯式、靜態型別)                              | 這是最根本的差異，Java 的型別安全和編譯期檢查更嚴格。                                             |
| **核心框架 (Core Framework)**     | Laravel                                     | Spring Boot                                          | Spring Boot 是基於 Spring Framework 的，大幅簡化了配置。                                          |
| **專案初始化 (Project Init)**     | `composer create-project laravel/laravel`   | **Spring Initializr** (`start.spring.io`)            | Spring Initializr 是官方的 Web 工具，用來產生專案結構，非常方便。                                 |
| **依賴管理 (Dependency Mgt.)**    | **Composer** (`composer.json`)              | **Maven** (`pom.xml`) 或 **Gradle** (`build.gradle`) | Maven 和 Gradle 是 Java 世界的標準，類似 Composer。                                               |
| **命令列工具 (CLI)**              | `php artisan`                               | `mvnw` (Maven) 或 `gradlew` (Gradle)                 | 沒有像 Artisan 那樣統一的工具，主要透過建置工具執行任務 (如打包、測試)。                          |
| **本地開發伺服器 (Dev Server)**   | `php artisan serve`                         | **內嵌伺服器** (Embedded Server)                     | Spring Boot 應用程式本身就是一個可執行的 JAR 檔，內建了 Tomcat/Jetty/Netty。                      |
| **路由 (Routing)**                | `routes/web.php`, `routes/api.php`          | **Controller 中的註解 (Annotations)**                | Laravel 用檔案定義路由；Spring Boot 在 Controller 方法上用 `@GetMapping`, `@PostMapping` 等註解。 |
| **控制器 (Controller)**           | `app/Http/Controllers`                      | `@RestController`, `@Controller`                     | `@RestController` 直接回傳 JSON，對應 API 開發。`@Controller` 用於傳統 MVC，回傳視圖。            |
| **ORM (資料庫操作)**              | **Eloquent** (Active Record 模式)           | **JPA / Hibernate** (Data Mapper 模式)               | JPA 是 Java 的持久化標準，Hibernate 是最流行的實現。你需要定義 `Entity` 和 `Repository`。         |
| **資料庫遷移 (Migrations)**       | `php artisan migrate`                       | **Flyway** 或 **Liquibase**                          | 這兩者是 Java 生態系中最主流的資料庫版本控制工具，需要整合進專案。                                |
| **視圖/模板引擎 (View/Template)** | **Blade** (`.blade.php`)                    | **Thymeleaf**                                        | Thymeleaf 是 Spring Boot 推薦的模板引擎。但現代架構更常前後端分離。                               |
| **設定檔 (Configuration)**        | `.env` 檔案, `config/` 目錄                 | `application.properties` 或 `application.yml`        | Spring Boot 將所有設定集中在一個檔案，支援多環境配置 (profiles)。                                 |
| **依賴注入/服務容器 (DI/IoC)**    | Service Container, `app()->make()`          | **Spring IoC Container** (`@Autowired`)              | Spring 的核心就是 IoC 和 DI。透過 `@Autowired` 註解自動注入依賴，非常強大。                       |
| **驗證 (Validation)**             | Form Requests, `Validator::make()`          | **Bean Validation** (`@Valid`, `@NotNull` 等)        | 在 DTO (Data Transfer Object) 的屬性上直接加註解來定義驗證規則。                                  |
| **認證/授權 (Auth)**              | Laravel Breeze/Jetstream, Sanctum, Passport | **Spring Security**                                  | Spring Security 功能極其強大且靈活，但學習曲線也比 Laravel 的內建方案陡峭。                       |
| **測試 (Testing)**                | PHPUnit, Pest                               | **JUnit**, **Mockito**                               | JUnit 是單元測試框架，Mockito 用於建立模擬物件 (Mock)。                                           |
| **排程任務 (Task Scheduling)**    | `app/Console/Kernel.php`                    | `@Scheduled` 註解                                    | 在方法上加上 `@Scheduled` 註解即可設定定時任務，非常簡單。                                        |
| **隊列/背景任務 (Queues/Jobs)**   | Laravel Queues (Redis, SQS)                 | **JMS**, **RabbitMQ**, **Kafka** 整合, `@Async`      | Spring 提供與多種訊息佇列的深度整合。`@Async` 可輕易實現非同步方法。                              |
