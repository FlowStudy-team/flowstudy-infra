# 内容搜索与资源存储契约

## Elasticsearch 内容搜索

`GET /api/v1/search/content` 为公开搜索接口，参数为 `keyword`、`contentType`、
`categoryId`、`tag`、`pageSize` 和 `searchAfter`。返回 `records`、`nextSearchAfter`
和 `hasNext`。客户端必须把 `nextSearchAfter` 原样传入下一页，不使用 `from + size`。

Core 使用 `flowstudy-content` 索引，标题、标签、摘要和正文参与全文检索，标题/标签
有更高权重，质量分参与 function score；公开状态过滤在查询层完成。

## OBS 资源

`POST /api/v1/resources/upload` 使用 multipart 字段 `file`，可选 `businessType` 和
`businessId`。生产环境通过 `SPRING_PROFILES_ACTIVE=obs` 使用华为云 OBS，开发环境
默认写入本地 Mock 目录。数据库只保存对象 Key、原始文件名、MIME、大小、SHA-256、
所有者和状态，不保存二进制内容。

`GET /api/v1/resources/{id}` 和 `DELETE /api/v1/resources/{id}` 均要求登录并校验资源所有者。
