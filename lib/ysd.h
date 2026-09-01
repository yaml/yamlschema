#ifndef YSD_H
#define YSD_H

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Returned strings use the platform C allocator.
 * Copy the value and release it with free().
 */
char *ysd_call(const char *operation, const char *input);
char *ysd_version(void);

#ifdef __cplusplus
}
#endif

#endif
