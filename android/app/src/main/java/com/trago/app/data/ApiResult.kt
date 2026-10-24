package com.trago.app.data

sealed class ApiResult<out T> {
    data class Success<T>(val data: T) : ApiResult<T>()
    data class Failure(
        val message: String,
        val code: String? = null,
        val statusCode: Int? = null,
    ) : ApiResult<Nothing>()
}
