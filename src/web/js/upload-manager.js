/**
 * 多文件并行上传管理器
 * 支持：并行上传（最多5个）、暂停、取消、断点续传
 */

class UploadManager {
    constructor(options = {}) {
        this.maxConcurrent = options.maxConcurrent || 5;
        this.chunkSize = options.chunkSize || 1024 * 1024; // 1MB chunks
        this.apiBase = options.apiBase || '';
        this.token = options.token || '';
        
        this.queue = []; // 待上传队列
        this.activeUploads = new Map(); // 正在进行的上传
        this.paused = false;
        this.cancelled = false;
        
        this.onProgress = options.onProgress || (() => {});
        this.onComplete = options.onComplete || (() => {});
        this.onError = options.onError || (() => {});
        this.onStatusChange = options.onStatusChange || (() => {});
    }

    /**
     * 添加上传任务
     * @param {File} file - 文件对象
     * @param {string} parentId - 父文件夹ID
     * @returns {string} - 任务ID
     */
    addFile(file, parentId = null) {
        const taskId = `upload_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
        const task = {
            id: taskId,
            file: file,
            parentId: parentId,
            status: 'pending', // pending, uploading, paused, completed, failed
            progress: 0,
            uploadedSize: 0,
            totalSize: file.size,
            speed: 0,
            startTime: null,
            xhr: null,
            retryCount: 0,
            maxRetries: 3
        };
        
        this.queue.push(task);
        this.onStatusChange(task);
        this.processQueue();
        
        return taskId;
    }

    /**
     * 批量添加文件
     * @param {FileList} files - 文件列表
     * @param {string} parentId - 父文件夹ID
     * @returns {string[]} - 任务ID数组
     */
    addFiles(files, parentId = null) {
        const taskIds = [];
        for (const file of files) {
            taskIds.push(this.addFile(file, parentId));
        }
        return taskIds;
    }

    /**
     * 处理上传队列
     */
    async processQueue() {
        if (this.paused || this.cancelled) return;
        
        // 获取待上传的任务
        const pendingTasks = this.queue.filter(t => t.status === 'pending');
        const activeCount = this.activeUploads.size;
        const availableSlots = this.maxConcurrent - activeCount;
        
        if (pendingTasks.length === 0 || availableSlots <= 0) return;
        
        // 并行上传最多5个文件
        const tasksToUpload = pendingTasks.slice(0, availableSlots);
        
        for (const task of tasksToUpload) {
            this.startUpload(task);
        }
    }

    /**
     * 开始上传单个文件
     * @param {Object} task - 上传任务
     */
    async startUpload(task) {
        if (this.paused || this.cancelled) return;
        
        task.status = 'uploading';
        task.startTime = Date.now();
        this.activeUploads.set(task.id, task);
        this.onStatusChange(task);
        
        try {
            // 检查是否支持断点续传
            const canResume = await this.checkUploadStatus(task);
            
            if (canResume && task.uploadedSize > 0) {
                // 断点续传
                await this.resumeUpload(task);
            } else {
                // 新上传
                await this.uploadFile(task);
            }
        } catch (error) {
            console.error('Upload error:', error);
            
            if (task.retryCount < task.maxRetries && !this.cancelled) {
                task.retryCount++;
                task.status = 'pending';
                this.onStatusChange(task);
                
                // 延迟重试
                setTimeout(() => {
                    if (!this.paused && !this.cancelled) {
                        this.startUpload(task);
                    }
                }, 2000 * task.retryCount);
            } else {
                task.status = 'failed';
                this.activeUploads.delete(task.id);
                this.onError(task, error);
                this.onStatusChange(task);
                this.processQueue();
            }
        }
    }

    /**
     * 检查上传状态（用于断点续传）
     * @param {Object} task - 上传任务
     * @returns {boolean} - 是否支持续传
     */
    async checkUploadStatus(task) {
        try {
            const response = await fetch(`${this.apiBase}/files/upload/status`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${this.token}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    filename: task.file.name,
                    size: task.file.size
                })
            });
            
            if (response.ok) {
                const data = await response.json();
                if (data.uploaded > 0) {
                    task.uploadedSize = data.uploaded;
                    task.progress = (data.uploaded / task.totalSize) * 100;
                    return true;
                }
            }
        } catch (error) {
            console.log('Check upload status failed:', error);
        }
        return false;
    }

    /**
     * 上传文件
     * @param {Object} task - 上传任务
     */
    uploadFile(task) {
        return new Promise((resolve, reject) => {
            const formData = new FormData();
            formData.append('file', task.file);
            if (task.parentId) {
                formData.append('parent_id', task.parentId);
            }

            const xhr = new XMLHttpRequest();
            task.xhr = xhr;

            // 上传进度
            xhr.upload.onprogress = (e) => {
                if (e.lengthComputable) {
                    task.uploadedSize = e.loaded;
                    task.progress = (e.loaded / e.total) * 100;
                    
                    // 计算速度
                    const elapsed = (Date.now() - task.startTime) / 1000;
                    if (elapsed > 0) {
                        task.speed = e.loaded / elapsed;
                    }
                    
                    this.onProgress(task);
                    this.onStatusChange(task);
                }
            };

            xhr.onload = () => {
                if (xhr.status === 200) {
                    task.status = 'completed';
                    task.progress = 100;
                    this.activeUploads.delete(task.id);
                    this.onComplete(task);
                    this.onStatusChange(task);
                    this.processQueue();
                    resolve(task);
                } else {
                    reject(new Error(xhr.responseText || 'Upload failed'));
                }
            };

            xhr.onerror = () => {
                reject(new Error('Network error'));
            };

            xhr.onabort = () => {
                reject(new Error('Upload aborted'));
            };

            xhr.open('POST', `${this.apiBase}/files/upload`);
            xhr.setRequestHeader('Authorization', `Bearer ${this.token}`);
            xhr.send(formData);
        });
    }

    /**
     * 断点续传
     * @param {Object} task - 上传任务
     */
    resumeUpload(task) {
        return new Promise((resolve, reject) => {
            // 使用分片上传实现断点续传
            const start = task.uploadedSize;
            const end = Math.min(start + this.chunkSize, task.totalSize);
            const chunk = task.file.slice(start, end);

            const formData = new FormData();
            formData.append('chunk', chunk);
            formData.append('filename', task.file.name);
            formData.append('offset', start);
            formData.append('total', task.totalSize);
            if (task.parentId) {
                formData.append('parent_id', task.parentId);
            }

            const xhr = new XMLHttpRequest();
            task.xhr = xhr;

            xhr.upload.onprogress = (e) => {
                if (e.lengthComputable) {
                    const chunkProgress = (e.loaded / e.total) * (end - start);
                    task.uploadedSize = start + chunkProgress;
                    task.progress = (task.uploadedSize / task.totalSize) * 100;
                    
                    const elapsed = (Date.now() - task.startTime) / 1000;
                    if (elapsed > 0) {
                        task.speed = task.uploadedSize / elapsed;
                    }
                    
                    this.onProgress(task);
                    this.onStatusChange(task);
                }
            };

            xhr.onload = () => {
                if (xhr.status === 200) {
                    const response = JSON.parse(xhr.responseText);
                    
                    if (response.completed) {
                        // 上传完成
                        task.status = 'completed';
                        task.progress = 100;
                        this.activeUploads.delete(task.id);
                        this.onComplete(task);
                        this.onStatusChange(task);
                        this.processQueue();
                        resolve(task);
                    } else {
                        // 继续上传下一片
                        task.uploadedSize = response.uploaded;
                        this.resumeUpload(task).then(resolve).catch(reject);
                    }
                } else {
                    reject(new Error(xhr.responseText || 'Upload failed'));
                }
            };

            xhr.onerror = () => reject(new Error('Network error'));
            xhr.onabort = () => reject(new Error('Upload aborted'));

            xhr.open('POST', `${this.apiBase}/files/upload/chunk`);
            xhr.setRequestHeader('Authorization', `Bearer ${this.token}`);
            xhr.send(formData);
        });
    }

    /**
     * 暂停所有上传
     */
    pause() {
        this.paused = true;
        
        // 暂停所有正在进行的上传
        for (const task of this.activeUploads.values()) {
            if (task.xhr) {
                task.xhr.abort();
            }
            task.status = 'paused';
            this.onStatusChange(task);
        }
        
        this.activeUploads.clear();
    }

    /**
     * 恢复上传
     */
    resume() {
        this.paused = false;
        
        // 将暂停的任务重新加入队列
        for (const task of this.queue) {
            if (task.status === 'paused') {
                task.status = 'pending';
                this.onStatusChange(task);
            }
        }
        
        this.processQueue();
    }

    /**
     * 取消指定任务
     * @param {string} taskId - 任务ID
     */
    cancel(taskId) {
        const task = this.queue.find(t => t.id === taskId);
        if (!task) return;
        
        if (task.status === 'uploading' && task.xhr) {
            task.xhr.abort();
            this.activeUploads.delete(taskId);
        }
        
        task.status = 'cancelled';
        this.onStatusChange(task);
        
        // 从队列中移除
        const index = this.queue.indexOf(task);
        if (index > -1) {
            this.queue.splice(index, 1);
        }
        
        this.processQueue();
    }

    /**
     * 取消所有上传
     */
    cancelAll() {
        this.cancelled = true;
        
        // 取消所有正在进行的上传
        for (const [taskId, task] of this.activeUploads) {
            if (task.xhr) {
                task.xhr.abort();
            }
            task.status = 'cancelled';
            this.onStatusChange(task);
        }
        
        this.activeUploads.clear();
        this.queue = [];
    }

    /**
     * 重试失败的任务
     * @param {string} taskId - 任务ID
     */
    retry(taskId) {
        const task = this.queue.find(t => t.id === taskId);
        if (!task || task.status !== 'failed') return;
        
        task.status = 'pending';
        task.retryCount = 0;
        this.onStatusChange(task);
        this.processQueue();
    }

    /**
     * 获取所有任务
     * @returns {Array} - 任务列表
     */
    getTasks() {
        return [...this.queue];
    }

    /**
     * 获取统计信息
     * @returns {Object} - 统计信息
     */
    getStats() {
        const total = this.queue.length;
        const pending = this.queue.filter(t => t.status === 'pending').length;
        const uploading = this.queue.filter(t => t.status === 'uploading').length;
        const completed = this.queue.filter(t => t.status === 'completed').length;
        const failed = this.queue.filter(t => t.status === 'failed').length;
        const paused = this.queue.filter(t => t.status === 'paused').length;
        
        return {
            total,
            pending,
            uploading,
            completed,
            failed,
            paused,
            activeCount: this.activeUploads.size
        };
    }

    /**
     * 是否有正在上传的文件
     * @returns {boolean}
     */
    hasActiveUploads() {
        return this.activeUploads.size > 0 || this.queue.some(t => t.status === 'pending');
    }
}

// 导出上传管理器
window.UploadManager = UploadManager;
